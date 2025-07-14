pub use super::generated_api::api::plugin_ids::{
    PluginIds as ProtobufPluginIds, SwarmVersion as ProtobufSwarmVersion,
};
use crate::data::PluginIds;

use std::convert::TryFrom;
use std::path::PathBuf;

impl TryFrom<ProtobufPluginIds> for PluginIds {
    type Error = &'static str;
    fn try_from(protobuf_plugin_ids: ProtobufPluginIds) -> Result<Self, &'static str> {
        Ok(PluginIds {
            plugin_id: protobuf_plugin_ids.plugin_id as u32,
            swarm_pid: protobuf_plugin_ids.swarm_pid as u32,
            initial_cwd: PathBuf::from(protobuf_plugin_ids.initial_cwd),
            client_id: protobuf_plugin_ids.client_id as u16,
        })
    }
}

impl TryFrom<PluginIds> for ProtobufPluginIds {
    type Error = &'static str;
    fn try_from(plugin_ids: PluginIds) -> Result<Self, &'static str> {
        Ok(ProtobufPluginIds {
            plugin_id: plugin_ids.plugin_id as i32,
            swarm_pid: plugin_ids.swarm_pid as i32,
            initial_cwd: plugin_ids.initial_cwd.display().to_string(),
            client_id: plugin_ids.client_id as u32,
        })
    }
}

impl TryFrom<&str> for ProtobufSwarmVersion {
    type Error = &'static str;
    fn try_from(swarm_version: &str) -> Result<Self, &'static str> {
        Ok(ProtobufSwarmVersion {
            version: swarm_version.to_owned(),
        })
    }
}
