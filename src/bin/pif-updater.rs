use std::env;
use std::fs;
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::process::{Command, Stdio};
use std::thread::sleep;
use std::time::Duration;

const PIF_APK: &str = "/data/system/PIF.apk";
const PIF_INFO_TMP: &str = "/data/system/pif_info_tmp";
const PIF_INFO: &str = "/data/pif_info";
const OEM_DIR: &str = "/data/local/oemports10t";

fn run(cmd: &str, args: &[&str]) -> String {
    let output = Command::new(cmd)
        .args(args)
        .output()
        .unwrap_or_else(|_| panic!("failed to run command {}", cmd));
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn silent_kill(process: &str) {
    let _ = Command::new("killall")
        .arg(process)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

fn curl_details() {
    let _ = run(
        "curl",
        &[
            "-s",
            "https://raw.githubusercontent.com/Danda420/OemPorts10T-PIF/pif-apk/info.txt",
            "-o",
            PIF_INFO_TMP,
        ],
    );
    sleep(Duration::from_secs(1));
    retry_details_if_fail();
}

fn retry_details_if_fail() {
    if let Ok(metadata) = fs::metadata(PIF_INFO_TMP) {
        if metadata.len() < 100 {
            println!("Failed retrieving PIF Info, retrying...");
            curl_details();
        }
    } else {
        println!("Failed retrieving PIF Info, retrying...");
        curl_details();
    }
}

fn fetch_info() {
    loop {
        println!("Checking internet connection...");

        let mut child = Command::new("nc")
            .args(&["google.com", "80"])
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .expect("failed to spawn nc");

        if let Some(mut stdin) = child.stdin.take() {
            let _ = stdin.write_all(b"GET http://google.com HTTP/1.0\n\n");
        }

        if let Ok(status) = child.wait() {
            if status.success() {
                println!("Connected to internet, fetching PIF Info!");
                curl_details();
                break;
            }
        }

        sleep(Duration::from_secs(2));
    }
}

fn curl_pif() {
    let _ = run(
        "curl",
        &[
            "-s",
            "https://raw.githubusercontent.com/Danda420/OemPorts10T-PIF/pif-apk/PIF.apk",
            "-o",
            PIF_APK,
        ],
    );
    sleep(Duration::from_secs(1));
    retry_pif_if_fail();
}

fn retry_pif_if_fail() {
    if let Ok(metadata) = fs::metadata(PIF_APK) {
        if metadata.len() < 1000 {
            println!("Failed retrieving PIF.apk, retrying...");
            curl_pif();
        }
    } else {
        println!("Download failed, retrying...");
        curl_pif();
    }
}

fn hellyeah_dir() {
    if !Path::new(OEM_DIR).exists() {
        let _ = fs::create_dir_all(OEM_DIR);
        let _ = fs::set_permissions(OEM_DIR, fs::Permissions::from_mode(0o777));
        let _ = Command::new("chown").args(&["root:root", OEM_DIR]).status();
    }
}

fn push_pif_json(path: &str) {
    hellyeah_dir();
    let dest = format!("{}/pif.json", OEM_DIR);
    let _ = fs::copy(path, &dest);
    let _ = fs::set_permissions(&dest, fs::Permissions::from_mode(0o777));
    let _ = Command::new("chown").args(&["root:root", &dest]).status();
    silent_kill("com.google.android.gms.unstable");
}

fn push_keybox_xml(path: &str) {
    hellyeah_dir();
    let dest = format!("{}/keybox.xml", OEM_DIR);
    let _ = fs::copy(path, &dest);
    let _ = fs::set_permissions(&dest, fs::Permissions::from_mode(0o777));
    let _ = Command::new("chown").args(&["root:root", &dest]).status();
    silent_kill("com.android.vending");
}

fn md5sum(path: &str) -> Option<String> {
    let output = Command::new("md5sum").arg(path).output().ok()?;
    let text = String::from_utf8_lossy(&output.stdout);
    Some(text.split_whitespace().next()?.to_string())
}

fn main_logic() {
    fetch_info();

    let pif_info_tmp_md5 = md5sum(PIF_INFO_TMP);
    let pif_info_md5 = md5sum(PIF_INFO);

    println!("+------------------------------+");
    println!("|         PIF.apk INFO         |");
    println!("+------------------------------+");
    if let Ok(info_content) = fs::read_to_string(PIF_INFO_TMP) {
        print!("{}", info_content);
    }
    println!("--------------------------------");

    if pif_info_tmp_md5 != pif_info_md5 {
        println!("New Version Found! Downloading...");
        curl_pif();
        let _ = fs::copy(PIF_INFO_TMP, PIF_INFO);
        println!("Installing latest PIF.apk");
        
        let _ = Command::new("pm").args(&["install", PIF_APK]).status();
        silent_kill("com.google.android.gms.unstable");
        silent_kill("com.android.vending");
        let _ = Command::new("pkill").arg("systemui").status();
        println!("PIF.apk updated!");
    } else {
        println!("Your PIF.apk version is already the latest one!");
    }

    if Path::new(PIF_INFO_TMP).exists() {
        let _ = fs::remove_file(PIF_INFO_TMP);
    }
    if Path::new(PIF_APK).exists() {
        let _ = fs::remove_file(PIF_APK);
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() > 1 {
        let mut i = 1;
        let mut executed_flag = false;
        
        while i < args.len() {
            match args[i].as_str() {
                "-p" => {
                    if i + 1 < args.len() {
                        push_pif_json(&args[i + 1]);
                        executed_flag = true;
                        i += 1;
                    }
                }
                "-k" => {
                    if i + 1 < args.len() {
                        push_keybox_xml(&args[i + 1]);
                        executed_flag = true;
                        i += 1;
                    }
                }
                _ => {}
            }
            i += 1;
        }
        
        if !executed_flag {
            main_logic();
        }
    } else {
        main_logic();
    }
}