# frozen_string_literal: true

require 'sinatra'
require 'sinatra/json'
require 'json'
require 'timeout'
require 'stringio'
require 'thread'
require_relative '../lib/sucheme'

set :public_folder, File.join(__dir__, 'public')
set :port, 4567

STDOUT_MUTEX = Mutex.new

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

  output_buffer = StringIO.new
  result_str = nil
  error_msg = nil

  begin
    env = Sucheme::Evaluator.make_sandbox_env

    STDOUT_MUTEX.synchronize do
      old_stdout = $stdout
      $stdout = output_buffer
      begin
        result = Timeout.timeout(5) do
          Sucheme::Evaluator.eval_source(code, env)
        end
        result_str = result.is_a?(Sucheme::SchemeVoid) ? nil : result.to_s
      ensure
        $stdout = old_stdout
      end
    end
  rescue Timeout::Error
    error_msg = 'Timeout: execution exceeded 5 seconds'
  rescue Sucheme::SuchemeError => e
    error_msg = e.message
  rescue => e
    error_msg = "Internal error: #{e.message}"
  end

  output = output_buffer.string
  if error_msg
    json({ success: false, error: error_msg, output: output })
  else
    json({ success: true, output: output, result: result_str })
  end
end
