use std::error::Error;

slint::include_modules!();

fn main() -> Result<(), Box<dyn Error>> {
    let ui = IosWindow::new()?;
    ui.run()?;

    Ok(())
}
