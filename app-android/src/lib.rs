#![cfg(any(target_os = "android"))]

slint::include_modules!();

#[unsafe(no_mangle)]
fn android_main(app: slint::android::AndroidApp) {
    slint::android::init(app).unwrap();

    AndroidWindow::new().unwrap().run().unwrap();
}
