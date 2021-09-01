require 'json'
require 'line/bot'
require 'net/http'

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_id = ENV['LINE_CHANNEL_ID']
    config.channel_secret = ENV['LINE_CHANNEL_SECRET']
    config.channel_token = ENV['LINE_CHANNEL_TOKEN']
  }
end

def webhook(event:, context:)
  signature = event['headers']['x-line-signature']
  body = event['body']
  unless client.validate_signature(body, signature)
    puts 'signature_error' # for debug
    puts event['headers']
    return {statusCode: 400, body: JSON.generate('signature_error')}
  end

  events = client.parse_events_from(body)
  events.each do |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        # 転送
        code = 200
        message = event.message['text']
        code = teams_send(message, ENV['TEAMS_HOOK'])

        # LINEへ結果報告
        res_message = '転送完了'
        if code != 200 then
          res_message = '転送失敗 code[' + code  + ']'
        end
        client.reply_message(event['replyToken'], {
          type: 'text',
          text: res_message
        })
      end
    end
  end

  {statusCode: 200, body: JSON.generate('done')}
end

def teams_send(message, uri)
  # 転送
  uri = URI.parse(uri)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true
  req  = Net::HTTP::Post.new(uri.request_uri)
  data = {
    'text' => message
  }.to_json
  req.body = data
  res = https.request(req)
  return res.code.to_i
end
