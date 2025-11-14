use std::error::Error;

slint::include_modules!();

use slint::wgpu_27::{WGPUConfiguration, WGPUSettings, wgpu};

fn main() -> Result<(), Box<dyn Error>> {
    let mut wgpu_settings = WGPUSettings::default();
    wgpu_settings.device_required_features = wgpu::Features::PUSH_CONSTANTS;
    wgpu_settings.device_required_limits.max_push_constant_size = 16;

    slint::BackendSelector::new()
        .require_wgpu_27(WGPUConfiguration::Automatic(wgpu_settings))
        .select()
        .expect("Unable to create Slint backend with WGPU based renderer");

    let ui = LinuxWindow::new()?;
    ui.run()?;

    Ok(())
}
