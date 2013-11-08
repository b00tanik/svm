require File.expand_path('analyzer/analyzer')
require 'thread'

helper = Analyzer.new($stdout)

threads_count = 4

['pos', 'neg'].each do |tone|
  puts "Analyze tone "+tone+"\n"
  thread_files = Array.new(threads_count)
  helper.get_files(tone).each do |file|
    unless ['.', '..'].include?(file)
      file_thread_num = rand(threads_count)
      thread_files[file_thread_num]=[] if thread_files[file_thread_num].nil?
      thread_files[file_thread_num] += ['data/'+tone+'/'+file]
    end
  end

  threads = []
  total_files = 0
  pos_files = 0
  neg_files = 0
  mutex = Mutex.new
  threads_count.times do |thread_num|
    threads << Thread.new(thread_files[thread_num]) do |file_list|
      file_list.each do |filename|
        analyze_result = helper.analyze(IO.read(filename))
        mutex.synchronize do
          total_files+=1
          if analyze_result>0
            pos_files+=1
          else
            neg_files+=1
          end
        end
        # puts "File "+filename+" get "+analyze_result.to_s
      end
      puts "Thread #"+thread_num.to_s+" ended"+"\n"
    end
  end

  threads.each do |t|
    t.join
  end

  puts "Analyze complete for tone #{tone}. "
  puts "Pos: #{((pos_files.to_f/total_files)*100).to_i} %"
  puts "Neg: #{((neg_files.to_f/total_files)*100).to_i} %"
end
