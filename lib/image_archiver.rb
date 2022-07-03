# image_archiver.rb - Handles the logging of images to text files. An imgur link is created from an image's CDN
# url and used in the log. In cases where imgur is unavailable, the image is posted to a private channel on another
# server and another CDN url is generated.
require "uri"
require "net/http"
require "json"
require "open-uri"

class ImageArchiver
  def initialize(cdn_url, filename)
    @api_uri = "https://api.imgur.com/3/image"
    @cdn_url = cdn_url
    @filename = filename
    @images_archive_channel = BOT.channel(ServerSettings::IMAGES_ARCHIVE_CHANNEL_ID)
  end

  def convert_cdn_to_imgur
    url = URI(@api_uri)

    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["Authorization"] = "Client-ID #{CLIENT_ID}"
    request.set_form_data('image': @cdn_url)
    response = https.request(request)

    case response.code
    when '200'
      JSON.parse(response.body)["data"]["link"]
    when '400'
      "There was/were attachment(s) to this message, but they are unavailable."
    else
      message = @images_archive_channel.send_file(convert_image_to_drbstringio)
      message.attachments[0].url
    end
  end

  private

  class DrbStringIO < StringIO
    attr_accessor :path
  end

  def convert_image_to_drbstringio 
    drbstringio = DrbStringIO.new(open(@cdn_url).read)
    drbstringio.path = @filename
    drbstringio
  end
end