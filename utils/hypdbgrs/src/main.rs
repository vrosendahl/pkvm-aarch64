use std::{
    fs::File,
    io::Read,
    os::unix::io::AsRawFd,
    str,
};
use clap::Parser;
use clap_num::maybe_hex;
use colored::Colorize;

const DBG_BUFF_SIZE: usize = 0x20000;

const MAGIC: u8 = 0xDE;
const COUNT_SHARED: u8 = 1;
const PRINT_S2_MAPPINGS: u8 = 2;
const PRINT_RAMLOG: u8 = 3;

#[derive(Parser)]
#[command(version, about, long_about = None)]
struct Cli {
    call: String,
    #[clap(short, long, default_value="hyp", value_parser=parse_target)]
    target: u64,
    #[clap(short, long, default_value_t=0x40000000, value_parser=maybe_hex::<u64>)]
    addr: u64,
    #[clap(short, long, default_value_t=0x10000000, value_parser=maybe_hex::<u64>)]
    size: u64,
    #[clap(short, long, default_value_t=0, value_parser=maybe_hex::<u64>)]
    lock: u64,
}

#[repr(C)]
pub struct CountSharedParams {
    pub dlen: u32,
    pub id: u64,
    pub size: u64,
    pub lock: u64,
}

#[repr(C)]
pub struct S2MappingParams {
    pub dlen: u32,
    pub id: u64,
    pub addr: u64,
    pub size: u64,
}

nix::ioctl_readwrite!(count_shared_ioctl, MAGIC, COUNT_SHARED, CountSharedParams);
nix::ioctl_readwrite!(print_s2_mappings_ioctl, MAGIC, PRINT_S2_MAPPINGS, S2MappingParams);
nix::ioctl_none!(print_ramlog_ioctl, MAGIC, PRINT_RAMLOG);

/* clap crate allows to use custom parsers for opts and args */
fn parse_target(s: &str) -> Result<u64, String> {
    match s {
        "hyp" => Ok(0),
        "host" => Ok(1),
        "guest" => Ok(2),
        _ => Err(String::from(s)),
    }
}

fn print_kernel_buffer(file: &mut File) {
    let mut bytes: [u8; DBG_BUFF_SIZE] = [0; DBG_BUFF_SIZE];
    let _result = file.read_exact(&mut bytes);
    let str = match str::from_utf8(&bytes) {
        Ok(v) => v,
        Err(e) => panic!("{} {}",
                         "Reading kernel buffer: Invalid UTF-8 sequence:".red(),
                         e),
    };
    println!("{}", "kernel buffer result:".yellow());
    println!("{}", str);
}

fn main() {
    let mut file = match File::open("/dev/hypdbg") {
        Err(why) => panic!("{} {}",
                           "couldn't open /dev/hypdbg:".red(),
                           why),
        Ok(file) => file,
    };

    let args = Cli::parse();
    match args.call.as_str() {
        "count_shared" => {
            let mut serv_struct = CountSharedParams {
                dlen: 0,
                id: args.target,
                size: args.size,
                lock: args.lock,
            };
            let _result = match unsafe {
                count_shared_ioctl(file.as_raw_fd(), &mut serv_struct)
            } {
                Ok(v) => v,
                Err(e) => panic!("{} {}",
                                 "count_shared_ioctl error:".red(),
                                 e)
            };
            print_kernel_buffer(&mut file);
        },
        "print_s2_mappings" => {
            let mut serv_struct = S2MappingParams {
                dlen: 0,
                id: args.target,
                addr: args.addr,
                size: args.size,
            };
            let _result = match unsafe {
                print_s2_mappings_ioctl(file.as_raw_fd(), &mut serv_struct)
            } {
                Ok(v) => v,
                Err(e) => panic!("{} {}",
                                 "print_s2_mappings_ioctl error:".red(),
                                 e),
            };
            print_kernel_buffer(&mut file);
        },
        "print_ramlog" => {
            unsafe {
                let _ = print_ramlog_ioctl(file.as_raw_fd());
            };
        },
        _ => {
            println!("{} {}",
                     "Unrecognized argument:".red(),
                     args.call.as_str().blue());
        },
    }
}

