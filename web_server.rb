require 'webrick'

root = File.expand_path 'logs/'
server = WEBrick::HTTPServer.new :Port => 8000, :DocumentRoot => root

server.mount_proc "/" do |req, res|
  begin
    res.body = File.read(File.join(root, req.path))
  rescue Errno::ENOENT
    res.body = "Error retrieving log"
  end
end

trap 'INT' do server.shutdown end

server.start