//! power_log 持久化 —— CSV 全量重写 + 原子替换
//!
//! 存储位置:`$XDG_DATA_HOME/wattwatch/powerlog.csv`(默认 `~/.local/share/wattwatch/powerlog.csv`)
//!
//! 文件格式(每行一条采样,`#` 开头为注释,容错解析):
//! ```text
//! # unix秒,功率W,充电标志(0/1)
//! 1723456789,12.34,1
//! 1723462789,8.50,0
//! ```

use crate::monitor::PowerSample;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};

/// 默认存储路径(遵循 XDG 规范,不创建目录)。
pub fn default_powerlog_path() -> PathBuf {
    let data_home = std::env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            std::env::var_os("HOME")
                .map(|h| PathBuf::from(h).join(".local/share"))
                .unwrap_or_else(|| PathBuf::from("."))
        });
    data_home.join("wattwatch").join("powerlog.csv")
}

/// 全量保存:先写临时文件再原子 rename,避免崩溃/断电写坏文件。
///
/// 失败时返回 `Err`(调用方按"本次未持久化"处理,不影响内存数据)。
pub fn save_powerlog(path: &Path, samples: &[PowerSample]) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let tmp = path.with_extension("csv.tmp");
    {
        let mut f = fs::File::create(&tmp)?;
        for (ts, power, charging) in samples {
            writeln!(f, "{},{},{}", ts, power, if *charging { 1 } else { 0 })?;
        }
    }
    fs::rename(&tmp, path)?;
    Ok(())
}

/// 加载全部历史采样(旧 → 新)。
///
/// 文件不存在时返回空;损坏/无法解析的行静默跳过,不影响其余数据。
pub fn load_powerlog(path: &Path) -> Vec<PowerSample> {
    let Ok(file) = fs::File::open(path) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for line in BufReader::new(file).lines().map_while(Result::ok) {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let mut parts = line.split(',');
        let Some(ts) = parts.next().and_then(|s| s.trim().parse::<i64>().ok()) else {
            continue;
        };
        let Some(power) = parts.next().and_then(|s| s.trim().parse::<f32>().ok()) else {
            continue;
        };
        let Some(ch) = parts.next().and_then(|s| s.trim().parse::<u8>().ok()) else {
            continue;
        };
        out.push((ts, power, ch != 0));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 临时文件路径(测试用,带进程号避免冲突)
    fn tmp_path(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!("wattwatch_test_{}_{}", std::process::id(), name))
    }

    /// 保存 → 加载闭环,顺序与内容保持一致。
    #[test]
    fn save_load_roundtrip() {
        let path = tmp_path("roundtrip.csv");
        let samples = vec![
            (1_723_456_789, 12.34, true),
            (1_723_462_789, 8.50, false),
            (1_723_468_789, 0.0, true),
        ];
        save_powerlog(&path, &samples).unwrap();
        let loaded = load_powerlog(&path);
        assert_eq!(loaded, samples);
        let _ = fs::remove_file(&path);
    }

    /// 文件不存在时返回空,不报错。
    #[test]
    fn load_missing_file_returns_empty() {
        let path = tmp_path("missing.csv");
        assert!(load_powerlog(&path).is_empty());
    }

    /// 损坏行被跳过,其余正常解析。
    #[test]
    fn load_skips_corrupt_lines() {
        let path = tmp_path("corrupt.csv");
        fs::write(
            &path,
            "# comment\n1723456789,12.34,1\nbad,line,here\n1789,abc,1\n1723462789,8.50,0\n",
        )
        .unwrap();
        let loaded = load_powerlog(&path);
        assert_eq!(loaded.len(), 2);
        assert_eq!(loaded[0], (1_723_456_789, 12.34, true));
        assert_eq!(loaded[1], (1_723_462_789, 8.50, false));
        let _ = fs::remove_file(&path);
    }

    /// 幂等:重复保存不产生残留临时文件。
    #[test]
    fn save_is_idempotent() {
        let path = tmp_path("idempotent.csv");
        let samples = vec![(100, 5.0, false)];
        save_powerlog(&path, &samples).unwrap();
        save_powerlog(&path, &samples).unwrap();
        assert!(!path.with_extension("csv.tmp").exists());
        assert_eq!(load_powerlog(&path), samples);
        let _ = fs::remove_file(&path);
    }
}
