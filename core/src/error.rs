//! Erros do núcleo Geny Assistant.

use thiserror::Error;

/// Erro unificado do núcleo.
#[derive(Debug, Error)]
pub enum CoreError {
    /// Ferramenta solicitada não está registrada no catálogo.
    #[error("ferramenta nao encontrada: {0}")]
    ToolNotFound(String),

    /// Parâmetros enviados pelo modelo violam o esquema da ferramenta.
    #[error("parametros invalidos para '{tool}': {reason}")]
    Validation { tool: String, reason: String },

    /// Falha durante a execução de uma ferramenta.
    #[error("execucao de ferramenta falhou: {0}")]
    Execution(String),

    /// Falha no backend de IA (local, remoto ou self-hosted).
    #[error("backend de IA: {0}")]
    Backend(String),

    /// Ação sensível foi negada ou não recebeu confirmação humana.
    #[error("acao negada ou sem confirmacao: {0}")]
    ConfirmationDenied(String),

    /// Erro interno inesperado.
    #[error("erro interno: {0}")]
    Internal(String),
}

/// Resultado padrão das operações do núcleo.
pub type Result<T> = std::result::Result<T, CoreError>;
