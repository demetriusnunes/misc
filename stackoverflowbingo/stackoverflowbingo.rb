require 'hpricot'
require 'openssl'
require 'uri'
require 'net/https'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
WIKI_HOME = 'https://stackoverflow.fogbugz.com/'
TRANSCRIPTS_PATH = '?W4'
PAGES_FILE = 'pages.dat'
WORDS_FILE = 'words.txt'

def fetch(uri_str, limit = 10)
  # You should choose better exception.
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0
  url = URI.parse(uri_str)
  req = Net::HTTP::Get.new(url.request_uri)
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = url.scheme == 'https' ? true : false
  response = http.request(req)
  case response
    when Net::HTTPSuccess     then response.body
    when Net::HTTPRedirection then fetch(response['location'], limit - 1)
  else
    response.error!
  end
end

def pages
  doc = Hpricot(fetch(WIKI_HOME + TRANSCRIPTS_PATH))
  transcript_paths = (doc/'a.uvb').map { |e| e.attributes['href'] }

  open(PAGES_FILE, "w+") { |file|
    transcript_paths.each { |transcript_path|
      transcript_url = transcript_path =~ /http/ ? transcript_path : "#{WIKI_HOME}#{transcript_path}"
      puts "Reading #{transcript_url}"
      doc = Hpricot(fetch(transcript_url))
      (doc/'div.post p').each { |p| file.puts p.inner_text }
    }
  }
end

def words
  dict = {}
  pages = open(PAGES_FILE).read
  words = pages.gsub(/[^\w|']/, " ").split
  words.each { |w| 
    word = w.downcase
    dict[word] ||= 0
    dict[word] = dict[word] + 1
  }

  sorted = dict.inject([]) { |arr, wordcount| 
      arr << wordcount
    }.sort_by { |pair| pair.last }.reverse

  open(WORDS_FILE, "w+") { |file|
    sorted.each { |wordcount|
      file.puts wordcount.join(",")
    }
  }
end

puts "Usage: #{$0} [w|p]" if ARGV.empty?
pages if ARGV.include?("p")
words if ARGV.include?("w")