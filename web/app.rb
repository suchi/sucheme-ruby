# frozen_string_literal: true

require 'sinatra'
require 'sinatra/json'
require 'json'
require_relative '../lib/sucheme'

set :public_folder, File.join(__dir__, 'public')
set :port, 4567

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

post '/eval' do
  content_type :json
  body = request.body.read
  data = begin
           JSON.parse(body)
         rescue JSON::ParserError
           {}
         end
  code = data['code'] || ''

  begin
    env = Sucheme::Evaluator.make_global_env

    output_buffer = StringIO.new
    old_stdout = $stdout
    $stdout = output_buffer

    result = Timeout.timeout(5) do
      Sucheme::Evaluator.eval_source(code, env)
    end

    $stdout = old_stdout

    output = output_buffer.string
    result_str = result.is_a?(Sucheme::SchemeVoid) ? nil : result.to_s

    json({ success: true, output: output, result: result_str })
  rescue Timeout::Error
    $stdout = old_stdout rescue nil
    json({ success: false, error: 'Timeout: execution exceeded 5 seconds' })
  rescue Sucheme::SuchemeError => e
    $stdout = old_stdout rescue nil
    json({ success: false, error: e.message })
  rescue => e
    $stdout = old_stdout rescue nil
    json({ success: false, error: "Internal error: #{e.message}" })
  end
end
