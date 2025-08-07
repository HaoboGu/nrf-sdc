use std::env;
use std::path::PathBuf;

fn main() {
    // Save the third party repo path to the env
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let third_party_repo_path = manifest_dir.join("third_party");
    let third_party_repo_path_str = third_party_repo_path.to_string_lossy();
    println!("cargo:THIRD_PARTY_REPO_PATH={}", third_party_repo_path_str);
}
