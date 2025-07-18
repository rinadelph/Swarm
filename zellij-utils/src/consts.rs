//! Swarm program-wide constants.

use crate::home::find_default_config_dir;
use directories::ProjectDirs;
use include_dir::{include_dir, Dir};
use lazy_static::lazy_static;
use std::{path::PathBuf, sync::OnceLock};
use uuid::Uuid;

pub const SWARM_CONFIG_FILE_ENV: &str = "SWARM_CONFIG_FILE";
pub const SWARM_CONFIG_DIR_ENV: &str = "SWARM_CONFIG_DIR";
pub const SWARM_LAYOUT_DIR_ENV: &str = "SWARM_LAYOUT_DIR";
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
pub const DEFAULT_SCROLL_BUFFER_SIZE: usize = 10_000;
pub static SCROLL_BUFFER_SIZE: OnceLock<usize> = OnceLock::new();
pub static DEBUG_MODE: OnceLock<bool> = OnceLock::new();

pub const SYSTEM_DEFAULT_CONFIG_DIR: &str = "/etc/swarm";
pub const SYSTEM_DEFAULT_DATA_DIR_PREFIX: &str = system_default_data_dir();

pub static SWARM_DEFAULT_THEMES: Dir = include_dir!("$CARGO_MANIFEST_DIR/assets/themes");

pub fn session_info_cache_file_name(session_name: &str) -> PathBuf {
    session_info_folder_for_session(session_name).join("session-metadata.kdl")
}

pub fn session_layout_cache_file_name(session_name: &str) -> PathBuf {
    session_info_folder_for_session(session_name).join("session-layout.kdl")
}

pub fn session_info_folder_for_session(session_name: &str) -> PathBuf {
    SWARM_SESSION_INFO_CACHE_DIR.join(session_name)
}

pub fn create_config_and_cache_folders() {
    if let Err(e) = std::fs::create_dir_all(&SWARM_CACHE_DIR.as_path()) {
        log::error!("Failed to create cache dir: {:?}", e);
    }
    if let Some(config_dir) = find_default_config_dir() {
        if let Err(e) = std::fs::create_dir_all(&config_dir.as_path()) {
            log::error!("Failed to create config dir: {:?}", e);
        }
    }
    // while session_info is a child of cache currently, it won't necessarily always be this way,
    // and so it's explicitly created here
    if let Err(e) = std::fs::create_dir_all(&SWARM_SESSION_INFO_CACHE_DIR.as_path()) {
        log::error!("Failed to create session_info cache dir: {:?}", e);
    }
}

const fn system_default_data_dir() -> &'static str {
    if let Some(data_dir) = std::option_env!("PREFIX") {
        data_dir
    } else {
        "/usr"
    }
}

lazy_static! {
    pub static ref SWARM_PROJ_DIR: ProjectDirs =
        ProjectDirs::from("org", "Swarm Contributors", "Swarm").unwrap();
    pub static ref SWARM_CACHE_DIR: PathBuf = SWARM_PROJ_DIR.cache_dir().to_path_buf();
    pub static ref SWARM_SESSION_CACHE_DIR: PathBuf = SWARM_PROJ_DIR
        .cache_dir()
        .to_path_buf()
        .join(format!("{}", Uuid::new_v4()));
    pub static ref SWARM_PLUGIN_PERMISSIONS_CACHE: PathBuf =
        SWARM_CACHE_DIR.join("permissions.kdl");
    pub static ref SWARM_SESSION_INFO_CACHE_DIR: PathBuf =
        SWARM_CACHE_DIR.join(VERSION).join("session_info");
    pub static ref SWARM_STDIN_CACHE_FILE: PathBuf =
        SWARM_CACHE_DIR.join(VERSION).join("stdin_cache");
    pub static ref SWARM_PLUGIN_ARTIFACT_DIR: PathBuf = SWARM_CACHE_DIR.join(VERSION);
    pub static ref SWARM_SEEN_RELEASE_NOTES_CACHE_FILE: PathBuf =
        SWARM_CACHE_DIR.join(VERSION).join("seen_release_notes");
}

pub const FEATURES: &[&str] = &[
    #[cfg(feature = "disable_automatic_asset_installation")]
    "disable_automatic_asset_installation",
];

#[cfg(not(target_family = "wasm"))]
pub use not_wasm::*;

#[cfg(not(target_family = "wasm"))]
mod not_wasm {
    use lazy_static::lazy_static;
    use std::collections::HashMap;
    use std::path::PathBuf;

    // Convenience macro to add plugins to the asset map (see `ASSET_MAP`)
    //
    // Plugins are taken from:
    //
    // - `swarm-utils/assets/plugins`: When building in release mode OR when the
    //   `plugins_from_target` feature IS NOT set
    // - `swarm-utils/../target/wasm32-wasip1/debug`: When building in debug mode AND the
    //   `plugins_from_target` feature IS set
    macro_rules! add_plugin {
        ($assets:expr, $plugin:literal) => {
            $assets.insert(
                PathBuf::from("plugins").join($plugin),
                #[cfg(any(not(feature = "plugins_from_target"), not(debug_assertions)))]
                include_bytes!(concat!(
                    env!("CARGO_MANIFEST_DIR"),
                    "/assets/plugins/",
                    $plugin
                ))
                .to_vec(),
                #[cfg(all(feature = "plugins_from_target", debug_assertions))]
                include_bytes!(concat!(
                    env!("CARGO_MANIFEST_DIR"),
                    "/../target/wasm32-wasip1/debug/",
                    $plugin
                ))
                .to_vec(),
            );
        };
    }

    lazy_static! {
        // Swarm asset map
        pub static ref ASSET_MAP: HashMap<PathBuf, Vec<u8>> = {
            let mut assets = std::collections::HashMap::new();
            add_plugin!(assets, "compact-bar.wasm");
            add_plugin!(assets, "status-bar.wasm");
            add_plugin!(assets, "tab-bar.wasm");
            add_plugin!(assets, "strider.wasm");
            add_plugin!(assets, "session-manager.wasm");
            add_plugin!(assets, "configuration.wasm");
            add_plugin!(assets, "plugin-manager.wasm");
            add_plugin!(assets, "about.wasm");
            add_plugin!(assets, "share.wasm");
            add_plugin!(assets, "multiple-select.wasm");
            add_plugin!(assets, "intro-screen.wasm");
            add_plugin!(assets, "my-custom-manager.wasm");
            assets
        };
    }
}

#[cfg(unix)]
pub use unix_only::*;

#[cfg(unix)]
mod unix_only {
    use super::*;
    use crate::envs;
    pub use crate::shared::set_permissions;
    use lazy_static::lazy_static;
    use nix::unistd::Uid;
    use std::env::temp_dir;

    pub const SWARM_SOCK_MAX_LENGTH: usize = 108;

    lazy_static! {
        static ref UID: Uid = Uid::current();
        pub static ref SWARM_TMP_DIR: PathBuf = temp_dir().join(format!("swarm-{}", *UID));
        pub static ref SWARM_TMP_LOG_DIR: PathBuf = SWARM_TMP_DIR.join("swarm-log");
        pub static ref SWARM_TMP_LOG_FILE: PathBuf = SWARM_TMP_LOG_DIR.join("swarm.log");
        pub static ref SWARM_SOCK_DIR: PathBuf = {
            let mut ipc_dir = envs::get_socket_dir().map_or_else(
                |_| {
                    SWARM_PROJ_DIR
                        .runtime_dir()
                        .map_or_else(|| SWARM_TMP_DIR.clone(), |p| p.to_owned())
                },
                PathBuf::from,
            );
            ipc_dir.push(VERSION);
            ipc_dir
        };
        pub static ref WEBSERVER_SOCKET_PATH: PathBuf = SWARM_SOCK_DIR.join("web_server_bus");
    }
}
