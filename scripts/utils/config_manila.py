import json
import os
import argparse
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("data_manila_export", help="data manila export parameter in slipstream (e.g. ss-get data_manila_export)")
parser.add_argument("-s", "--src",
                    help="source of mount directory (default=/automount_ifb)")
parser.add_argument("-d", "--dst",
                    help="destination of mount directory (default=/ifb/data)")
args = parser.parse_args()


def config_manila(data_manila_export, src_dir="/automount_ifb", dst_dir="/ifb/data"):
    #dict = os.popen('ss-get data_manila_export').read()
    print(data_manila_export)
    print(src_dir)
    print(dst_dir)
    data = json.loads(data_manila_export)
    os.makedirs(src_dir, exist_ok=True)
    with open('/etc/auto.master', 'w') as f:
        f.write('/automount_ifb /etc/auto.ifb_manila')

    ifb_manila_file = open("/etc/auto.ifb_manila", "w")
    for k, v in data.items():
        src = src_dir + "/" + k
        dst = dst_dir + "/" + k
        os.symlink(src, dst)
        ifb_manila_file.write(k + " -fstype=nfs,rw " + v + "\n")
    ifb_manila_file.close()
    command = ['service', 'autofs', 'restart']
    subprocess.call(command, shell=True)


if __name__ == '__main__':
    if args.src and args.dst:
        config_manila(args.data_manila_export, src_dir=args.src, dst_dir=args.dst)
    elif args.src and not args.dst:
        config_manila(args.data_manila_export, src_dir=args.src)
    elif not args.src and args.dst:
        config_manila(args.data_manila_export, dst_dir=args.dst)
    else:
        config_manila(args.data_manila_export)
