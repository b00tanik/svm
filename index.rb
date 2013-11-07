require 'rubygems'
require 'sinatra'
require File.expand_path('analyzer/analyzer')

get '/' do
  erb :index, :layout => :"layout/main"
end

get '/stat' do
  erb :"stat/show", :layout => :"layout/main"
end

get '/learn' do
    Analyzer.new($stdout).learning_step
end

get '/analyze' do
  Analyzer.new($stdout).learning_step
end