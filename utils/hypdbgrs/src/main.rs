use std::{
    fs::File,
    io::{Read, Write},
    os::unix::io::AsRawFd,
    str,
};
use clap::{Parser, Subcommand};
use clap_num::maybe_hex;
use colored::Colorize;

const MAGIC: u8             = 0xDE;
const PRINT_S2_MAPPINGS: u8 = 2;
const COUNT_SHARED: u8      = 3;
const PRINT_RAMLOG: u8      = 4;

const UNUSED_FIELD8: u8     = 0;
const UNUSED_FIELD32: u32   = 0;
const UNUSED_FIELD64: u64   = 0;

#[derive(Parser)]
#[command(version, about,
    long_about = "Utility allows to communicate with hypervisor through the
hypdbg-drv kernel module. Kernel config must be built with enabled
KVM_ARM_HYP_DEBUG_* options. Number of calls are suported.
Try ./hypdbgrs help <subcommand>")]
struct Cli {
    #[command(subcommand)]
    call: Calls,
}

#[derive(Subcommand)]
enum Calls {
    /// Print stage 2 pages with attributes for the specified target
    /// in the range of address space [addr; addr + size]
    PrintS2Mappings(PrintS2MArgs),
    /// Count shared pages for the specified target in [0; size] range
    CountShared(CountSharedArgs),
    /// Print decrypted ramlog or dump encrypted ramlog to a specified file
    Ramlog(RamlogArgs),
}

#[derive(Parser)]
struct PrintS2MArgs {
    #[clap(short, long, default_value="hyp", value_parser=parse_target)]
    target: u32,
    #[clap(short, long, default_value_t=0x40000000, value_parser=maybe_hex::<u64>)]
    addr: u64,
    #[clap(short, long, default_value_t=0x10000000, value_parser=maybe_hex::<u64>)]
    size: u64,
}
#[derive(Parser)]
struct CountSharedArgs {
    #[clap(short, long, default_value="hyp", value_parser=parse_target)]
    target: u32,
    #[clap(short, long, default_value_t=0x10000000, value_parser=maybe_hex::<u64>)]
    size: u64,
    #[clap(short, long, default_value_t=0)]
    lock: u8,
}
#[derive(Parser)]
struct RamlogArgs {
    #[clap(short, long)]
    dump: bool,
    #[clap(short, long, default_value="ramlog_dump.log")]
    ofile_log: String,
}

/**
 * The struct has a summary of fields required by all ioctl calls.
 * Kernel module knows which fields are relevant to a specific call
 */
#[repr(C)]
pub struct IoctlParams {
    pub dlen: u32,
    pub id:   u32,
    pub addr: u64,
    pub size: u64,
    pub lock: u8,
    pub dump: u8,
}

nix::ioctl_readwrite!(count_shared_ioctl, MAGIC, COUNT_SHARED, IoctlParams);
nix::ioctl_readwrite!(print_s2_mappings_ioctl, MAGIC, PRINT_S2_MAPPINGS, IoctlParams);
nix::ioctl_readwrite!(ramlog_ioctl, MAGIC, PRINT_RAMLOG, IoctlParams);

/*
 * Custom parser for target option
 *
 * "guest" being interpreted as first guest (2) as well as "guest1" (2)
 * other guest targets containing id number which will be incremented to create
 * actual id to be passed in the hypdbg kernel module
 */
fn parse_target(s: &str) -> Result<u32, String> {
    match s {
        "hyp" =>     Ok(0),
        "host" =>    Ok(1),
        _ => if s.starts_with("guest") {
                let (_, id_str) = s.split_at(5);
                if id_str.is_empty() {
                    return Ok(2);
                } else {
                    let id_num: u32 = id_str.parse()
                        .expect("Specify target as guest<id>");
                    return Ok(id_num + 1);
                }
             } else { Err(String::from(s)) },
    }
}

fn print_kernel_buffer(file: &mut File, len: u32) {
    let mut bytes = vec![0; len as usize];
    file.read(&mut bytes).expect("Read from kernel overflows buffer!");
    let str = match str::from_utf8(&bytes) {
        Ok(v) => v,
        Err(e) => panic!("{} {}",
                         "Reading kernel buffer: Invalid UTF-8 sequence:".red(),
                         e),
    };
    println!("{}", "kernel buffer result:".yellow());
    println!("{}", str);
}

fn dump_print_ramlog(input: &mut File, output: &String, len: u32) {
    let mut buffer = vec![0; len as usize];
    input.read(&mut buffer).expect("Read from kernel overflows buffer!");

    let mut dump_file = File::create(&output).unwrap();
    match dump_file.write_all(&buffer) {
        Ok(v) => v,
        Err(e) => panic!("{} {}", "Can't write ramlog to file:".red(), e),
    };
    println!("{} {}", "Ramlog dumped to:".yellow(), output.blue());
}

fn main() -> Result<(), core::fmt::Error> {
    let args = Cli::parse();

    let mut file = match File::open("/dev/hypdbg") {
        Err(why) => panic!("{} {}",
                           "couldn't open /dev/hypdbg:".red(),
                           why),
        Ok(file) => file,
    };

    match args.call {
        Calls::PrintS2Mappings(args) => {
            let mut serv_struct = IoctlParams {
                dlen: 0,
                id: args.target,
                addr: args.addr,
                size: args.size,
                lock: UNUSED_FIELD8,
                dump: UNUSED_FIELD8,
            };
            let _result = match unsafe {
                print_s2_mappings_ioctl(file.as_raw_fd(), &mut serv_struct)
            } {
                Ok(v) => v,
                Err(e) => panic!("{} {}",
                                 "print_s2_mappings_ioctl error:".red(),
                                 e),
            };
            print_kernel_buffer(&mut file, serv_struct.dlen);
        },
        Calls::CountShared(args) => {
            if args.target == 1 {

                println!("{}", "There is no big profit in a counting".yellow());
                println!("{}", "shared pages between host and host.".yellow());
                println!("{}",
                    "Consider to change the target on hyp or guest#".yellow());

                return Ok(());
            }
            let mut serv_struct = IoctlParams {
                dlen: 0,
                id: args.target,
                size: args.size,
                lock: args.lock,
                addr: UNUSED_FIELD64,
                dump: UNUSED_FIELD8,
            };
            let _result = match unsafe {
                count_shared_ioctl(file.as_raw_fd(), &mut serv_struct)
            } {
                Ok(v) => v,
                Err(e) => panic!("{} {}",
                                 "count_shared_ioctl error:".red(),
                                 e)
            };
            print_kernel_buffer(&mut file, serv_struct.dlen);
        },
        Calls::Ramlog(args) => {
            let mut serv_struct = IoctlParams {
                dlen: 0,
                dump: if args.dump {1} else {0},
                id: UNUSED_FIELD32,
                addr: UNUSED_FIELD64,
                size: UNUSED_FIELD64,
                lock: UNUSED_FIELD8,
            };
            let _result = match unsafe {
                ramlog_ioctl(file.as_raw_fd(), &mut serv_struct)
            } {
                Ok(v) => v,
                Err(e) => panic!("{} {}",
                                 "ramlog_ioctl error:".red(),
                                 e),
            };
            if args.dump {
                dump_print_ramlog(&mut file, &args.ofile_log, serv_struct.dlen);
            }
        },
    }
    return Ok(());
}
