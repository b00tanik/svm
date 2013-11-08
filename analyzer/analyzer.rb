require 'rubygems'
require 'mongo'
require 'json'
include Mongo
require 'thread'

class Analyzer

  def initialize(new_stream)
    @stream = new_stream
  end

  def get_files(tone)
    Dir.entries('data/'+tone)
  end

  def store(filename, tone)
    text_words = Hash.new
    words_count = 0
    IO.read(filename).scan(/\w+/) do |word|
      if text_words[word].nil?
        text_words[word]=0.to_f
      end
      text_words[word]+=1
      words_count+=1
    end
    calc_weight(text_words, words_count, tone)
  end

  def calc_weight(data, count, sign = 'pos')
    data.each do |key, val|
      data[key]=100*(val.to_f / count)
      data[key]=-data[key] if sign=='neg'
    end
  end

  def learning_step()
    @stream<<'Start analyze'+"\n"
    teacher = get_file_words()

    collection = MongoClient.new('localhost', 27017).db("svm").collection('words')
    collection.ensure_index(:word, {:unique => 1})

    @stream<<'Analyzing words count '+teacher.size.to_s+"\n"

    cur_pos=0

    teacher.keys.each_slice(100) do |search_words|
      collection.find('word' => {'$in' => search_words}).each do |word_data|
        word = word_data['word']
        if (teacher[word]*10000).to_i != (word_data['word']*10000).to_i
          collection.update({_id: word_data['_id']}, {:word => word,
                                                      :score => merge_func(word_data['score'], teacher[word])})
        end

        teacher.delete(word)
      end
    end


    @stream<<'Writing to Mongo '+teacher.size.to_s+"\n"
    teacher = teacher.map do |key, value|
      {:word => key,
       :score => value} if !value.nil?
    end


    collection.insert(teacher)
    @stream<<'Finish '+teacher.size.to_s+"\n"

    teacher

  end

  def get_file_words()
    threads_count = 4


    final_words = Hash.new

    ['pos', 'neg'].each do |tone|
      thread_files = Array.new(threads_count)
      local_store=Hash.new

      @stream<< "Calc tone "+tone+"\n"
      ind =0
      self.get_files(tone).each do |file|
        unless ['.', '..'].include?(file)
          file_thread_num = ind % threads_count
          thread_files[file_thread_num]=[] if thread_files[file_thread_num].nil?
          thread_files[file_thread_num] += ['data/'+tone+'/'+file]
          ind+=1
        end
      end

      puts "Thread files size #{thread_files.size}"

      mutex = Mutex.new
      threads = []
      threads_count.times do |thread_num|
        threads << Thread.new(thread_files[thread_num]) do |file_list|
          file_list.each do |filename|
            store_data = self.store(filename, tone)
            mutex.synchronize do
              local_store[filename] = store_data
            end

          end
          @stream<< "Thread #"+thread_num.to_s+" ended"+"\n"
        end
      end

      threads.each do |t|
        t.join
      end

      tone_words = Hash.new
      local_store.each do |filename, words|
        tone_words.merge!(words) do |k, nv, ov|
          merge_func(nv, ov)
        end
      end

      final_words.merge!(tone_words) do |k, nv, ov|
        merge_func(nv, ov)
      end
    end

    final_words

  end

  def merge_func(a, b)
    (a+b)/2
  end


  def analyze(text)
    collection = MongoClient.new('localhost', 27017).db("svm").collection('words')
    search_words = text.scan(/\w+/)
    rating = 0
    collection.find('word' => {'$in' => search_words}).each do |word_data|
      rating+=word_data['score']
    end
    rating
  end
end




