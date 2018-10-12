#!/usr/bin/env python2.7
import collections
import argparse
from datetime import datetime


def log_reader(filename):
    with open(filename) as f_in:
        for line in f_in:
            if len(line) >= 22 and line[0] == '[' and line[15] == ']' and line[1:15].isdigit() \
                    and line[17:21] == '===>' and line.find(' for ') > -1:
                if line.strip().endswith('for building'):
                    continue
                log_rec = collections.namedtuple('record', ['stage', 'package', 'timestamp', 'ts_epoch'])
                log_rec.stage = line[22:].split()[0]
                log_rec.package = line.split(' for ')[-1].split()[0]
                log_rec.timestamp = datetime(*map(lambda x: int(x), (
                    line[1:5], line[5:7], line[7:9], line[9:11], line[11:13], line[13:15]
                )))
                log_rec.ts_epoch = float(log_rec.timestamp.strftime("%s"))

                yield log_rec


parser = argparse.ArgumentParser()
parser.add_argument('filename', help='ports build log filename')
parser.add_argument('--steps', help='show build steps', action="store_true", default=False)
args = parser.parse_args()

stats = dict()
prev_rec = collections.namedtuple('record', ['stage', 'package', 'timestamp', 'ts_epoch'])
for record in log_reader(args.filename):
    if (prev_rec.stage != record.stage or prev_rec.package != record.package) and type(prev_rec.ts_epoch) == float:
        if prev_rec.package not in stats:
            stats[prev_rec.package] = dict()
            stats[prev_rec.package]['__total__'] = 0.0
        if prev_rec.stage not in stats[prev_rec.package]:
            stats[prev_rec.package][prev_rec.stage] = {'count': 0, 'total_time': 0.0}

        stats[prev_rec.package][prev_rec.stage]['total_time'] += (record.ts_epoch - prev_rec.ts_epoch)
        stats[prev_rec.package][prev_rec.stage]['count'] += 1
        stats[prev_rec.package]['__total__'] += (record.ts_epoch - prev_rec.ts_epoch)

    prev_rec = record

total_time = 0.0
for item in sorted(stats.items(), key=lambda x: x[1]['__total__']):
    package = item[0]
    for stage in sorted(item[1]):
        if type(stats[package][stage]) == dict and args.steps:
            print ("%-40s %-5.0f seconds [execs : %d]" % (
                "%s[%s]" % (package, stage),
                stats[package][stage]['total_time'],
                stats[package][stage]['count']
            ))
    print ("%-40s %-5.0f seconds" % (package, stats[package]['__total__']))
    total_time += stats[package]['__total__']

print ("%-40s %-5.0f seconds" % ("*", total_time))
