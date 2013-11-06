class AnalyzeHelper
  @@words_store = Hash.new

  def get_files(tone)
    Dir.entries('../data/'+tone)
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
    @@words_store.merge!(text_words) do |k,nv,ov|
      @@words_store[k]=(nv+ov)/2
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

end