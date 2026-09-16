//! Binário do gerador de bindings UniFFI (TODO core-04).
//!
//! Uso (após `cargo build --features uniffi`):
//! ```sh
//! cargo run --features uniffi --bin uniffi-bindgen \
//!   generate --library target/release/libgeny_core.so \
//!   --language kotlin --out-dir ../android/app/src/main/gen-kotlin
//! ```

fn main() {
    uniffi::uniffi_bindgen_main()
}
