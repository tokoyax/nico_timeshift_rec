require 'open3'
require 'openssl'
require 'net/http'
require 'rexml/document'
require 'io/console'

EMAIL = ''
PASSWORD = ''
SAVE_DIR = ''

def login(mail, pass)
  host = 'secure.nicovideo.jp'
  path = '/secure/login?site=niconico'
  body = "mail=#{mail}&password=#{pass}"

  https             = Net::HTTP.new(host, 443)
  https.use_ssl     = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  response          = https.start { |https|
    https.post(path, body)
  }

  cookie = ''
  response['set-cookie'].split('; ').each do |st|
    if idx=st.index('user_session_')
      cookie = "user_session=#{st[idx..-1]}"
      break
    end
  end

  return cookie
end

def get_lv(url)
  url.match(/lv[0-9]+/)
end

def get_player_status(lv, cookie)
  host = 'watch.live.nicovideo.jp'
  path = "/api/getplayerstatus/#{lv}"
  http = Net::HTTP.new(host, 80)
  res = http.start do |http|
    http.get path, {Cookie: cookie}
  end
  doc = REXML::Document.new(res.body)
  res = {}
  res[:url] = doc.elements['getplayerstatus/rtmp/url'].text
  res[:ticket] = doc.elements['getplayerstatus/rtmp/ticket'].text
  res[:title] = doc.elements['getplayerstatus/stream/title'].text
  arr = []
  doc.elements['getplayerstatus/stream/quesheet'].each do |que|
    if content = que.text.match(/\/content.*/)
      arr.push content.to_s
    end
  end
  res[:contents] = arr
  res
end

def download(info, save_dir, file_name)
  info[:contents].each_with_index do |content, i|
    cmd = "rtmpdump -r #{info[:url]} -y mp4:#{content} -C S:#{info[:ticket]} -e -o #{save_dir}/#{file_name}_#{i}.flv"
    Open3.popen3(cmd) do |i, o, e, w|
      o.each do |line| p line end #=> "a\n",  "b\n"
      e.each do |line| p line end #=> "bar\n", "baz\n", "foo\n"
      p w.value #=> #<Process::Status: pid 32682 exit 0>
    end
  end
end

#######################################################################

print 'email:'
if EMAIL.empty?
  email = gets.chomp
else
  email = EMAIL
end
print "password:"
if PASSWORD.empty?
  password = STDIN.noecho(&:gets).chomp
else
  password = PASSWORD
end
cookie = login email, password

abort 'Login failed' if cookie.empty?

print "\nLogin successs\n"
print 'url:'
url = gets.chomp
lv = get_lv url

abort 'Could not get lv code' if lv.to_s.empty?

video_info = get_player_status lv, cookie

print 'file name:'
file_name = gets.chomp
print 'save dir:'
save_dir = gets.chomp
download video_info, save_dir, file_name

print 'Finish!!!!!'
exit 0
