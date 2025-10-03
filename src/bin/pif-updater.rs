use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};
use std::io::Write;
use std::thread::sleep;
use std::time::Duration;

const PIF_TMP: &str = "/data/system/pif_tmp.apk";
const PIF: &str = "/data/PIF.apk";

fn run(cmd: &str, args: &[&str]) -> String {
    let output = Command::new(cmd)
        .args(args)
        .output()
        .expect("failed to run command");
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn curl_pif() {
    let _ = run("curl", &[
        "-s",
        "https://raw.githubusercontent.com/Danda420/OemPorts10T-PIF/pif-apk/PIF.apk",
        "-o",
        PIF_TMP,
    ]);
    sleep(Duration::from_secs(1));
    retry_if_fail();
}

fn retry_if_fail() {
    if let Ok(metadata) = fs::metadata(PIF_TMP) {
        if metadata.len() < 1000 {
            println!("Failed retrieving PIF.apk, retrying...");
            curl_pif();
        }
    } else {
        println!("Download failed, retrying...");
        curl_pif();
    }
}

fn fetch_pif() {
    loop {
        println!("Checking internet connection...");

        let mut child = Command::new("nc")
            .args(&["google.com", "80"])
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .spawn()
            .expect("failed to spawn nc");

        if let Some(mut stdin) = child.stdin.take() {
            let _ = stdin.write_all(b"GET http://google.com HTTP/1.0\n\n");
        }

        if let Ok(status) = child.wait() {
            if status.success() {
                println!("Connected to internet, fetching latest PIF.apk!");
                curl_pif();
                break;
            }
        }

        sleep(Duration::from_secs(2));
    }
}

fn md5sum(path: &str) -> Option<String> {
    let output = Command::new("md5sum")
        .arg(path)
        .output()
        .ok()?;
    let text = String::from_utf8_lossy(&output.stdout);
    Some(text.split_whitespace().next()?.to_string())
}

fn main() {
    fetch_pif();

    let pif_tmp_md5 = md5sum(PIF_TMP);
    let pif_md5 = md5sum(PIF);

    if pif_tmp_md5 != pif_md5 {
        let _ = fs::copy(PIF_TMP, PIF);
        let _ = Command::new("pm").args(&["install", PIF]).status();
        let _ = Command::new("killall").arg("com.google.android.gms.unstable").status();
        let _ = Command::new("killall").arg("com.android.vending").status();
        println!("PIF.apk updated!");
    } else {
        println!("Your PIF.apk version is already the latest one!");
    }

    if Path::new(PIF_TMP).exists() {
        let _ = fs::remove_file(PIF_TMP);
    }
}

