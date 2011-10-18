#!/usr/bin/expect -f
#!/bin/sh

# Copyright (C) 2008  Antoine Mercadal
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

expect_user -re "(.*)\n"
puts "password: "
set password $expect_out(1,string)

set arguments "[lindex $argv 0] -v"
set path $argv0

#kill previous command
exec $path/../KillTunnel.sh $arguments

eval spawn $arguments

match_max 10000

set timeout 30

if {$password eq ""} {
    puts "USING PRIVATE KEY AUTHENTICATION\n"
	expect {
		"?sh: Error*" {puts "CONNECTION_ERROR"; exit};
		"*yes/no*" {send "yes\r"; exp_continue};
		"*Connection refused*" {puts "CONNECTION_REFUSED"; exit};
		"*Could not resolve hostname*" {puts "WRONG_HOSTNAME"; exit};
		"*Operation timed out*" {puts "CONNECTION_TIMEOUT"; exit};
		"*?assword:*" {puts "WRONG_PASSWORD"; exit;}
        "*Entering interactive session*" {puts "CONNECTED"; set timeout 0};
	}

} else {
    puts "USING PASSWORD AUTHENTICATION\n"
	expect {
		"?sh: Error*" {puts "CONNECTION_ERROR"; exit};
		"*yes/no*" {send "yes\r"; exp_continue};
		"*Connection refused*" {puts "CONNECTION_REFUSED"; exit};
		"*Could not resolve hostname*" {puts "WRONG_HOSTNAME"; exit};
		"*Operation timed out*" {puts "CONNECTION_TIMEOUT"; exit};
		"*?assword:*" {	send "$password\r"
						expect {
                                "*?assword:*" {puts "WRONG_PASSWORD"; exit;}
                                "*Entering interactive session*" {puts "CONNECTED"; set timeout 0}
                               }
					  };
		timeout {puts "CONNECTION_TIMEOUT"; exit}
	}
}

set timeout -1
expect {
	-re \w$ {sleep 5;exp_continue;}
	eof {exit}
}
