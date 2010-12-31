require 'net/imap'
require 'mail'
require File.join(File.dirname(__FILE__), '../zomg_inbox/traffic_controller')

class ImapJob
  @queue = :imap

  def self.perform(host, port, ssl, username, password)
    imap = Net::IMAP.new(host, port, ssl)
    imap.login(username, password)

    imap.select("INBOX")

    archive_messages = []
    messages = imap.fetch(1..-1, "(UID BODY.PEEK[HEADER.FIELDS (SUBJECT)] BODY.PEEK[HEADER.FIELDS (TO)])")
    if messages
      messages.each do |message|
        mid     = message.seqno
        uid     = message.attr["UID"]
        subject = message.attr["BODY[HEADER.FIELDS (SUBJECT)]"].sub("Subject ", '').chomp.chomp
        folder  = TrafficController.new(message.attr).destination

        if not imap.list('OtherInbox/', folder)
          puts "Creating folder OtherInbox/#{folder}"
          imap.create("OtherInbox/#{folder}")
        end

        puts "Processing #{uid} : #{subject} to #{folder}"
        imap.copy(mid, "OtherInbox/#{folder}")
        archive_messages << mid
      end
    end

    # archive email
    imap.store(archive_messages, "+FLAGS", [:Deleted]) if archive_messages.any?

    imap.disconnect
  end
end
