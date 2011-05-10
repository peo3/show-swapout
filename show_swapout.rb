#!/usr/bin/ruby

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
# See the COPYING file for license information.
#
# Copyright (c) 2011 peo3 <peo314159265@gmail.com>

if Process.euid != 0
	STDERR.puts 'Warning: Run as root! Otherwise you cannot get some data correctly.'
	sleep 3
end

pids = []
Dir.foreach("/proc/") do |file|
	if file =~ /\d+/
		pids << file
	end
end

SCRIPTS = ['python', 'ruby', 'sh']
procs = []
pids.each do |pid|
	path = "/proc/#{pid}/smaps"
	if not File.exist?(path)
		next
	end
	rss  = 0
	swap = 0
	IO.readlines(path).each do |line|
		if line =~ /^Rss:\s+(\d+) kB$/
			rss += $1.to_i
		elsif line =~ /^Swap:\s+(\d+) kB$/
			swap += $1.to_i
		end
	end

	path = "/proc/#{pid}/cmdline"
	cmdline = IO.read(path)
	if cmdline.include?("\0")
		args = cmdline.split("\0")
	else
		args = cmdline.split(' ')
	end

	if args.size == 0
		next
	end

	name = File.basename(args[0])
	if args.size > 1 and SCRIPTS.include?(name)
		def get_first_name(_args)
			_args.each do |arg|
				return arg if arg[0, 1] != '-'
			end
		end
		name1 = File.basename(get_first_name(args[1..-1]))
		name = "%s(%s)" % [name1, name]
	end

	procs << [swap, rss, pid, name]
end

buffers = cached = memtotal = memfree = swaptotal = swapfree = 0
path = "/proc/meminfo"
IO.readlines(path).each do |line|
	if line =~ /^Buffers:\s+(\d+) kB$/
		buffers = $1.to_i
	elsif line =~ /^Cached:\s+(\d+) kB$/
		cached = $1.to_i
	elsif line =~ /^MemTotal:\s+(\d+) kB$/
		memtotal = $1.to_i
	elsif line =~ /^MemFree:\s+(\d+) kB$/
		memfree = $1.to_i
	elsif line =~ /^SwapTotal:\s+(\d+) kB$/
		swaptotal = $1.to_i
	elsif line =~ /^SwapFree:\s+(\d+) kB$/
		swapfree = $1.to_i
	end
end
swap = swaptotal - swapfree
rss = memtotal - cached - buffers - memfree
procs << [swap, rss, 0, 'TOTAL']

puts "   SWAP     RSS   RATIO     PID NAME"
procs.sort{|a,b| a[0] <=> b[0]}.each do |procs|
	swap = procs[0]
	rss  = procs[1]
	pid  = procs[2]
	name = procs[3]

	def format(usage)
		if usage > 1024*1024
			return "%6.1fG" % [usage.to_f/1024/1024,]
		elsif usage > 1024
			return "%6.1fM" % [usage.to_f/1024,]
		else
			return "%6.1fk" % [usage.to_f,]
		end
	end

	ratio = swap.to_f*100/(swap+rss)
	ratio = "%6.1f%%" % [ratio,]

	puts "%s %s %s %7s %s" % [format(swap), format(rss), ratio, pid, name]
end
