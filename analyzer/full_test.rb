require File.expand_path('analyzer/analyzer')
MongoClient.new('localhost', 27017).drop_database('svm')
require File.expand_path('analyzer/test_learn')
require File.expand_path('analyzer/test_analyzer')