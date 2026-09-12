//! Gerenciador de sessão e contexto de conversa (memória de curto prazo).

use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

/// Papel de uma mensagem na conversa.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Role {
    User,
    Assistant,
    Tool,
    System,
}

/// Mensagem individual da conversa.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub role: Role,
    pub content: String,
    /// Identificador da chamada de ferramenta que gerou esta mensagem (se houver).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tool_call_id: Option<String>,
    /// Carimbo de data/hora em milissegundos desde a época Unix.
    pub at_ms: u64,
}

impl Message {
    /// Cria uma mensagem com o horário atual do dispositivo.
    pub fn now(role: Role, content: impl Into<String>) -> Self {
        Message {
            role,
            content: content.into(),
            tool_call_id: None,
            at_ms: now_ms(),
        }
    }

    /// Cria uma mensagem com identificador de chamada de ferramenta.
    pub fn tool_call(id: impl Into<String>, content: impl Into<String>) -> Self {
        Message {
            role: Role::Tool,
            content: content.into(),
            tool_call_id: Some(id.into()),
            at_ms: now_ms(),
        }
    }
}

/// Sessão de conversa com janela de contexto configurável.
#[derive(Debug, Clone)]
pub struct Session {
    pub id: String,
    pub created_at_ms: u64,
    messages: Vec<Message>,
    /// Número máximo de mensagens mantidas no contexto enviado ao modelo.
    pub max_context_messages: usize,
}

impl Session {
    /// Cria uma nova sessão vazia.
    pub fn new(id: impl Into<String>) -> Self {
        Session {
            id: id.into(),
            created_at_ms: now_ms(),
            messages: Vec::new(),
            max_context_messages: 24,
        }
    }

    /// Adiciona uma mensagem à sessão.
    pub fn push(&mut self, message: Message) {
        self.messages.push(message);
    }

    /// Atalho para mensagem do usuário.
    pub fn push_user(&mut self, content: impl Into<String>) {
        self.push(Message::now(Role::User, content));
    }

    /// Atalho para mensagem do assistente.
    pub fn push_assistant(&mut self, content: impl Into<String>) {
        self.push(Message::now(Role::Assistant, content));
    }

    /// Histórico completo da sessão.
    pub fn history(&self) -> &[Message] {
        &self.messages
    }

    /// Janela de contexto (últimas `max_context_messages` mensagens), que será
    /// enviada ao modelo. Mantém ordem cronológica.
    pub fn context_window(&self) -> Vec<Message> {
        let start = self
            .messages
            .len()
            .saturating_sub(self.max_context_messages.max(1));
        self.messages[start..].to_vec()
    }

    /// Remove mensagens antigas mantendo apenas as `keep_last` mais recentes.
    /// Usado pela política de retenção configurável do usuário.
    pub fn trim(&mut self, keep_last: usize) {
        let start = self.messages.len().saturating_sub(keep_last);
        self.messages.drain(..start);
    }

    /// Número de mensagens na sessão.
    pub fn len(&self) -> usize {
        self.messages.len()
    }

    /// Sessão vazia?
    pub fn is_empty(&self) -> bool {
        self.messages.is_empty()
    }
}

/// Horário atual em milissegundos desde a época Unix.
pub fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn janela_de_contexto_mantem_ultimas_mensagens() {
        let mut s = Session::new("s1");
        s.max_context_messages = 3;
        for i in 0..5 {
            s.push_user(format!("msg {i}"));
        }
        let window = s.context_window();
        assert_eq!(window.len(), 3);
        assert_eq!(window[0].content, "msg 2");
        assert_eq!(window[2].content, "msg 4");
    }

    #[test]
    fn trim_mantem_apenas_as_ultimas() {
        let mut s = Session::new("s2");
        for i in 0..10 {
            s.push_user(format!("m{i}"));
        }
        s.trim(2);
        assert_eq!(s.len(), 2);
        assert_eq!(s.history()[0].content, "m8");
    }

    #[test]
    fn mensagem_de_ferramenta_carrega_id() {
        let m = Message::tool_call("call-1", "{\"ok\":true}");
        assert_eq!(m.role, Role::Tool);
        assert_eq!(m.tool_call_id.as_deref(), Some("call-1"));
    }
}
