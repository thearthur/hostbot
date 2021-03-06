#!/usr/bin/env ruby

## Enable the next line for debugging and run this from the "lib" directory
if false
  $:.insert(0, ".")
  dev_append = "-dev"
  print "Running as a develoment bot...\n"
else
  dev_append = ""
end
require 'configbot/bghandler'
require 'configbot/confighandler'
require 'configbot/configbot_commands'
hostname = `/bin/hostname`
hostname = hostname.chomp()

pidfile = "/var/run/configbot#{dev_append}.pid"

if (File.exist?(pidfile))
  pf = File.open(pidfile, "r")
  old_pid = pf.readline
  pf.close
end
if (old_pid)
  pn = `ps -p #{old_pid}`
  if (pn.include?("conf") or pn.include?("ruby"))
    `kill #{old_pid};sleep 1`
  end
end

# First, let's daemonize
pid = fork
if pid
  Process.detach(pid)
  Process.exit(0)
end
Signal.trap('HUP', 'IGNORE')

# Now let's write the pid of the watching process
pf = File.open(pidfile, "w")
pf.puts($$)
pf.close

# Ok, now let's watch our children...
begin
  while pid = fork
    Process.wait( pid )
  end
rescue Exception=>e
  Process.kill('INT', pid)
  Process.exit(0)
end

### Let the children do what they do best ###

# The cred's we need to talk to the jabber server
jid      = "hostbot@bots.uahirise.org/#{hostname}#{dev_append}"
password = 'APassword'
server   = 'jabs.uahirise.org'
muc_jid  = "hostbots#{dev_append}@conference.uahirise.org"

module HiBot
  class ConfigHandler < HiBot::BotHandler
    def newSession( jid, muc )
      session = super( jid, muc )
      if jid.strip == 'tims@uahirise.org' || jid.strip == 'kfine@uahirise.org'
        session.newRS(HiBot::CommandResponseHandler)
      elsif jid.strip == @auth_info[:admin_muc_jid]
        session.newRS(HiBot::MUCResponseHandler)
      # elsif jid.strip == @auth_info[:admin_muc_jid]
        # session.newRS(HiBot::CommandResponseHandler)
      end
      return session
    end
  end
end

# How do we act on incoming messages?
msg_handler = HiBot::ConfigHandler.new( jid, password, server, muc_jid )
msg_handler.on_exception{begin; msg_handler.cleanup; rescue Exception => e; puts "Whoa, There was an error: #{e.message}"; ensure; Process.exit; end}

class LoadWatch < BGHandler::CronHandler
  def run()
    output = `uptime`
    if $? == 0
      # mach_load = output.gsub(/.*load average: /).split(' ').shift.to_f
      mach_load = output.gsub(/.*load average[s]*: /, '').gsub(/,/, '').split(",").shift.to_f
      if mach_load > 10
        self.getSession().say("Load alert #{mach_load}!")
      end
    else
    end
  end
end

# muc_session = msg_handler.getSession( muc_jid )
# muc_session = msg_handler.getSession( "#{muc_jid}/tim" )
# load = LoadWatch.new( delayTime=60, session=muc_session )

# Stop the main thread and just process events
begin
  Thread.stop
ensure
  File.delete(pidfile)
end

