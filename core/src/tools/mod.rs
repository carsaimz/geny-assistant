//! Sistema de ferramentas (tool calling) — registro, validação e catálogo.

pub mod catalog;
pub mod registry;
pub mod validator;

pub use registry::{ParamSpec, ParamType, ToolContext, ToolDefinition, ToolRegistry};
