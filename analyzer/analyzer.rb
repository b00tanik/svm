require 'rubygems'
require 'mongo'
require 'json'
require File.expand_path('analyze_helper')
include Mongo

helper = AnalyzeHelper.new

threads_count = 4
thread_files = Array.new(threads_count)

final_words = Hash.new

['pos', 'neg'].each do |tone|
  puts "Calc tone "+tone
  helper.get_files(tone).each do |file|
    unless ['.', '..'].include?(file)
      file_thread_num = rand(threads_count)
      thread_files[file_thread_num]=[] if thread_files[file_thread_num].nil?
      thread_files[file_thread_num] += ['../data/'+tone+'/'+file]
    end
  end

  threads = []
  threads_count.times do |thread_num|
    threads << Thread.new(thread_num) do |cur_num|
      thread_files[cur_num].each do |filename|
        helper.store(filename, tone)
      end
      puts "Thread #"+thread_num.to_s+" ended"
    end
  end

  threads.each do |t|
    t.join
  end

  final_words[tone] = helper.words_store
end


final_words['pos'].merge!(final_words['neg']) do |k,nv,ov|
  final_words['pos'][k]=(nv+ov)/2
end

final_words = final_words['pos']




