require 'rubygems'
require 'mongo'
require 'json'
include Mongo

class Analyzer


  @@words_store = Hash.new

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
    text_words = calc_weight(text_words, words_count, tone)
    @@words_store.merge!(text_words) do |k, nv, ov|
      merge_func(nv, ov)
    end
  end

  def calc_weight(data, count, sign = 'pos')
    data.each do |key, val|
      data[key]=100*(val.to_f / count)
      data[key]=-data[key] if sign=='neg'
    end
  end

  def words_store
    @@words_store
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
      puts "POS   "+(cur_pos+=100).to_s()+"\n"
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
    helper = self

    threads_count = 4
    thread_files = Array.new(threads_count)

    final_words = Hash.new

    ['pos', 'neg'].each do |tone|
      @@words_store=Hash.new
      @stream<< "Calc tone "+tone+"\n"
      helper.get_files(tone).each do |file|
        unless ['.', '..'].include?(file)
          file_thread_num = rand(threads_count)
          thread_files[file_thread_num]=[] if thread_files[file_thread_num].nil?
          thread_files[file_thread_num] += ['data/'+tone+'/'+file]
        end
      end

      threads = []
      threads_count.times do |thread_num|
        threads << Thread.new(thread_num) do |cur_num|
          thread_files[cur_num].each do |filename|
            helper.store(filename, tone)
          end
          @stream<< "Thread #"+thread_num.to_s+" ended"+"\n"
        end
      end

      threads.each do |t|
        t.join
      end

      final_words.merge!(@@words_store) do |k, nv, ov|
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




