#!/usr/bin/env ruby

if false
  $:.insert(0, ".")
  dev_append = "-dev"
else
  dev_append = ""
end

require 'configbot/bghandler'
require 'configbot/confighandler'
require 'configbot/puppet_commands'
hostname = `/bin/hostname`
hostname.chomp!
pidfile = "/var/run/muppetbot#{dev_append}.pid"

if (File.exist?(pidfile))
  pf = File.open(pidfile, "r")
  old_pid = pf.readline
  pf.close
end
pf = File.open(pidfile, "w")
pf.puts($$)
pf.close
if (old_pid)
  pn = `ps -p #{old_pid}`
  if (pn.include?("mup"))
  `kill -15 #{old_pid}`
  end
end
# The cred's we need to talk to the jabber server
jid      = "muppetbot@bots.uahirise.org/pastor-#{hostname}#{dev_append}"
password = 'AnotherPassword'
server   = 'jabs.uahirise.org'
muc_jid  = "hostbots#{dev_append}@conference.uahirise.org"

module HiBot

  class MuppetHandler < HiBot::BotHandler
    def newSession( jid, muc )
      session = super( jid, muc )
      jid_type = session.jid_type( jid )
      print "new session/response handler for #{jid} -- #{jid.strip} (#{jid_type})\n"
      if BotCommands.AdminJID.include?( "#{jid.strip}" )
        session.newRS(HiBot::MuppetCommandResponseHandler)
      elsif jid_type == :bot
        session.newRS(HiBot::AggregateResponseHandler)
      elsif jid_type == :admin_muc or jid_type == :admin
        session.newRS(HiBot::MuppetMUCResponseHandler)
      elsif jid_type == :muc
        session.newRS(HiBot::MUCResponseHandler)
      end
      return session
    end
  end

  ## MUPPET SPECIFIC IMPLEMENTATION ##
  class MuppetCommandResponseHandler < CommandResponseHandler
    def initialize (*args)
      super *args
      @acl_criteria.store(:bot_type, :muppetbot)
    end
  end

  class MuppetMUCResponseHandler < MUCResponseHandler
    def initialize( *args )
      super *args
      @acl_criteria.store(:bot_type, :muppetbot)
      # Hash of nick => DelayedNotifier
      @delayNotifiers = {}
    end

    # Watch for certains nodes to enter/exit the room
    def joinedRoom( nick )
      super( nick )
      if @delayNotifiers.key?(nick)
        @delayNotifiers.delete(nick).cancelled = true
      end
    end

    def leftRoom( nick )
      super( nick )
      if( watchNick?( nick ) )
        if ! @delayNotifiers.key?(nick)
	  @delayNotifiers[ nick ] = DelayedNotifier.new( 30 ) { say( "#{nick} left the room" ) }
	end
      end
    end

    def watchNick?( nick )
      nick =~ /cnode.*/
    end

  end

  class DelayedNotifier < BGHandler::DelayHandler
     attr_accessor :cancelled

     def initialize( delayTime, &block )
       super(delayTime, repeat=0, runTimeO=runTimeO)
       @block = block
       self.cancelled = false
     end

     def run()
       return if self.cancelled
       @block.call
     end
  end
####################################

end
# How do we act on incoming messages?
msg_handler = HiBot::MuppetHandler.new( jid, password, server, muc_jid )
msg_handler.on_exception{begin; msg_handler.cleanup; rescue Exception => e; puts "Whoa, There was an error: #{e.message}"; ensure; Process.exit; end}
# Stop the main thread and just process events
begin
  Thread.stop
ensure
  File.delete(pidfile)
end
