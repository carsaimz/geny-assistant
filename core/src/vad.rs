//! VAD — Voice Activity Detection (docs §7.2 · TODO core-01).
//!
//! **PT** Implementação de referência pura em Rust, usada pelo orquestrador
//! para enquadramento, decisão de fala e corte de silêncio. No Android, a
//! detecção neural (Silero ONNX via ONNX Runtime) substitui a energia RMS
//! quando o modelo está baixado — a interface de decisão é a mesma.
//! **EN** Pure-Rust reference implementation used by the orchestrator for
//! framing, speech decisions and silence trimming. On Android the neural
//! detector (Silero ONNX via ONNX Runtime) replaces RMS energy when the model
//! is downloaded — the decision interface is the same.
//!
//! Pipeline típico / typical pipeline:
//!
//! ```text
//! mic 16 kHz mono i16 → frames de 30 ms → VAD (energia ou Silero)
//!                     → buffer com pré-roll → trim de silêncio → STT
//! ```

use std::time::Duration;

/// Configuração do VAD de energia / energy VAD configuration.
#[derive(Debug, Clone, PartialEq)]
pub struct VadConfig {
    /// Taxa de amostragem (apenas 16 kHz é suportado pelos modelos on-device).
    pub sample_rate: u32,
    /// Duração do frame de análise / analysis frame length.
    pub frame: Duration,
    /// Limiar RMS (0.0–1.0, linear) que separa silêncio de fala.
    pub rms_threshold: f32,
    /// Frames extras de fala após o fim real (evita cortes bruscos).
    pub hangover: usize,
    /// Áudio de contexto mantido ANTES do início da fala.
    pub pre_roll: usize,
    /// Fala mais curta que isto não conta como voz (ruído/click).
    pub min_speech: Duration,
    /// Silêncio mais longo que isto encerra o segmento de fala.
    pub min_silence: Duration,
}

impl Default for VadConfig {
    fn default() -> Self {
        Self {
            sample_rate: 16_000,
            frame: Duration::from_millis(30),
            rms_threshold: 0.015,
            hangover: 8,
            pre_roll: 5,
            min_speech: Duration::from_millis(120),
            min_silence: Duration::from_millis(480),
        }
    }
}

impl VadConfig {
    /// Amostras por frame conforme a configuração.
    pub fn frame_samples(&self) -> usize {
        let samples = self.sample_rate as f64 * self.frame.as_secs_f64();
        (samples.round().max(1.0)) as usize
    }

    /// Frames cobertos por uma duração (arredonda para cima).
    pub fn frames_for(&self, d: Duration) -> usize {
        let frame_nanos = self.frame.as_nanos().max(1);
        (d.as_nanos() as usize).div_ceil(frame_nanos as usize)
    }
}

/// Decisão do VAD para um frame / per-frame VAD decision.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct VadDecision {
    /// Nível RMS linearizado do frame (0.0–1.0).
    pub level: f32,
    /// `true` quando o VAD considera o frame como fala.
    pub speech: bool,
    /// `true` apenas na transição silêncio→fala (bom para "ouvir acordou").
    pub speech_started: bool,
}

/// VAD por energia RMS com histerese e hangover (sem dependências).
///
/// Máquina de estados: silêncio → (frame acima do limiar) → fala →
/// (silêncio por `min_silence`, considerando hangover) → silêncio.
#[derive(Debug)]
pub struct EnergyVad {
    config: VadConfig,
    speaking: bool,
    hangover_left: usize,
    speech_frames: usize,
    silence_frames: usize,
}

impl EnergyVad {
    pub fn new(config: VadConfig) -> Self {
        Self {
            config,
            speaking: false,
            hangover_left: 0,
            speech_frames: 0,
            silence_frames: 0,
        }
    }

    pub fn config(&self) -> &VadConfig {
        &self.config
    }

    /// Processa um frame de PCM i16 mono e devolve a decisão.
    pub fn process(&mut self, frame: &[i16]) -> VadDecision {
        let level = rms_normalized(frame);
        let above = level >= self.config.rms_threshold;

        let mut speech_started = false;
        if above {
            self.speech_frames += 1;
            self.silence_frames = 0;
            self.hangover_left = self.config.hangover;
            if !self.speaking
                && self.speech_frames >= self.config.frames_for(self.config.min_speech)
            {
                self.speaking = true;
                speech_started = true;
            }
        } else {
            self.speech_frames = 0;
            if self.speaking {
                if self.hangover_left > 0 {
                    self.hangover_left -= 1;
                } else {
                    self.silence_frames += 1;
                    if self.silence_frames >= self.config.frames_for(self.config.min_silence) {
                        self.speaking = false;
                        self.silence_frames = 0;
                    }
                }
            }
        }

        VadDecision {
            level,
            speech: self.speaking,
            speech_started,
        }
    }

    /// Reinicia o estado entre gravações.
    pub fn reset(&mut self) {
        self.speaking = false;
        self.hangover_left = 0;
        self.speech_frames = 0;
        self.silence_frames = 0;
    }

    pub fn is_speaking(&self) -> bool {
        self.speaking
    }
}

/// Acumulador de áudio com pré-roll e corte de silêncio das pontas.
///
/// Alimenta-se de frames contíguos; [`SegmentBuffer::finish`] devolve o PCM
/// útil (mono i16, 16 kHz) pronto para o STT, ou `None` se nada de relevante
/// foi capturado.
#[derive(Debug)]
pub struct SegmentBuffer {
    config: VadConfig,
    pre_roll: std::collections::VecDeque<Vec<i16>>,
    collected: Vec<i16>,
    samples_seen: usize,
    speech_detected: bool,
}

impl SegmentBuffer {
    pub fn new(config: VadConfig) -> Self {
        let pre_roll = std::collections::VecDeque::with_capacity(config.pre_roll);
        Self {
            config,
            pre_roll,
            collected: Vec::new(),
            samples_seen: 0,
            speech_detected: false,
        }
    }

    /// Total de amostras processadas até agora (para métricas de latência).
    pub fn samples_seen(&self) -> usize {
        self.samples_seen
    }

    /// Adiciona um frame; `speech` vem da decisão do VAD.
    pub fn push(&mut self, frame: &[i16], speech: bool) {
        self.samples_seen = self.samples_seen.saturating_add(frame.len());
        if !speech {
            if !self.speech_detected {
                // Guarda pré-roll circular enquanto não há fala.
                self.pre_roll.push_back(frame.to_vec());
                let max_frames = self.config.pre_roll;
                while self.pre_roll.len() > max_frames {
                    self.pre_roll.pop_front();
                }
            }
            return;
        }
        if !self.speech_detected {
            self.speech_detected = true;
            for past in self.pre_roll.drain(..) {
                self.collected.extend_from_slice(&past);
            }
        }
        self.collected.extend_from_slice(frame);
    }

    /// Finaliza e devolve o PCM aparado (silêncio das pontas removido).
    pub fn finish(self) -> Option<Vec<i16>> {
        if !self.speech_detected || self.collected.is_empty() {
            return None;
        }
        Some(self.collected)
    }
}

/// RMS de um frame i16 normalizado para 0.0–1.0 (0x7FFF → 1.0).
pub fn rms_normalized(frame: &[i16]) -> f32 {
    if frame.is_empty() {
        return 0.0;
    }
    let sum_sq: f64 = frame.iter().map(|&s| (s as f64 / 32_768.0).powi(2)).sum();
    (sum_sq / frame.len() as f64).sqrt().clamp(0.0, 1.0) as f32
}

#[cfg(test)]
mod tests {
    use super::*;

    fn frame_of(config: &VadConfig, amplitude: f32) -> Vec<i16> {
        let n = config.frame_samples();
        vec![(amplitude * 32_000.0) as i16; n]
    }

    #[test]
    fn frame_samples_padrao_480() {
        let cfg = VadConfig::default();
        assert_eq!(cfg.frame_samples(), 480, "30 ms a 16 kHz = 480 amostras");
        assert_eq!(cfg.frames_for(Duration::from_millis(120)), 4);
        assert_eq!(cfg.frames_for(Duration::from_millis(481)), 17);
    }

    #[test]
    fn silencio_nao_gera_segmento() {
        let cfg = VadConfig::default();
        let mut vad = EnergyVad::new(cfg.clone());
        let mut buf = SegmentBuffer::new(cfg.clone());
        let quiet = frame_of(&cfg, 0.0005);
        for _ in 0..200 {
            let d = vad.process(&quiet);
            buf.push(&quiet, d.speech);
        }
        assert!(
            buf.finish().is_none(),
            "silêncio puro não deve produzir áudio"
        );
        assert!(!vad.is_speaking());
    }

    #[test]
    fn fala_com_pre_roll_e_hangover() {
        let cfg = VadConfig::default();
        let mut vad = EnergyVad::new(cfg.clone());
        let mut buf = SegmentBuffer::new(cfg.clone());
        let quiet = frame_of(&cfg, 0.0005);
        let loud = frame_of(&cfg, 0.35);

        for _ in 0..10 {
            let d = vad.process(&quiet);
            buf.push(&quiet, d.speech);
        }
        let mut got_start = false;
        for _ in 0..40 {
            let d = vad.process(&loud);
            got_start |= d.speech_started;
            buf.push(&loud, d.speech);
        }
        assert!(
            got_start,
            "transição silêncio→fala deve sinalizar speech_started"
        );

        let pcm = buf.finish().expect("fala deve produzir PCM");
        // Cálculo: min_speech=4 frames → fala "acorda" no 4º loud; os 3
        // anteriores caem no pré-roll. Pré-roll final = [q9,q10,l1,l2,l3] (5)
        // + l4..l40 (37) = 42 frames úteis.
        assert_eq!(pcm.len(), 42 * cfg.frame_samples());
        assert!(
            pcm.len() < 50 * cfg.frame_samples(),
            "pré-roll limitado a 5 frames"
        );
    }

    #[test]
    fn histerese_nao_corta_paleta_curta() {
        let cfg = VadConfig::default();
        let mut vad = EnergyVad::new(cfg.clone());
        let quiet = frame_of(&cfg, 0.0005);
        let loud = frame_of(&cfg, 0.35);
        for _ in 0..20 {
            vad.process(&loud);
        }
        assert!(vad.is_speaking());
        // Pausa curta (2 frames < min_silence 480 ms ≈ 16 frames): continua "falando".
        vad.process(&quiet);
        vad.process(&quiet);
        assert!(vad.is_speaking(), "hangover/min_silence deve manter a fala");
    }

    #[test]
    fn fala_curta_abaixo_de_min_speech_e_ignorada() {
        let cfg = VadConfig::default();
        let mut vad = EnergyVad::new(cfg.clone());
        let loud = frame_of(&cfg, 0.35);
        // min_speech = 120 ms = 4 frames; 2 frames não ativam.
        vad.process(&loud);
        vad.process(&loud);
        assert!(
            !vad.is_speaking(),
            "click/ruído curto não deve contar como fala"
        );
    }

    #[test]
    fn rms_normalizado_bordas() {
        assert_eq!(rms_normalized(&[]), 0.0);
        assert_eq!(rms_normalized(&[0; 480]), 0.0);
        let full = [i16::MAX; 480];
        let level = rms_normalized(&full);
        assert!((level - 1.0).abs() < 1e-3, "onda quadrada máxima → ~1.0");
        assert!(rms_normalized(&[-100; 480]) < 0.01);
    }
}
