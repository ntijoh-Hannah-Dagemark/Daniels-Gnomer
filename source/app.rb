require 'sinatra'
require 'sinatra/flash'
require_relative 'db/seed'

class App < Sinatra::Base 

    enable :sessions
    register Sinatra::Flash

    def db
        if @db == nil
            @db = SQLite3::Database.new('./db/db.sqlite')
            @db.results_as_hash = true
        end
        return @db
    end

    get '/manager/default' do
      load "./db/default.rb"
      flash[:success] = "Database Defaulted Successfully"
      redirect '/index'
    end

    get '/' do
        ##stuff
        # erb: (page)
        redirect "/index"
    end

    get '/game/:id' do |id|
        @people_db = db.execute("SELECT * FROM people")
        game_specific = "game#{id}"
        erb game_specific.to_sym
    end

    get '/index' do
        erb :index
    end

    get '/manage' do
        erb :manage
    end

    post "answer" do
        ansr = params["answer"]
        imgid = params["img_id"]
        path = "./../public/img/" + imgid.to_s + ".png"
        correct = db.execute("SELECT name FROM people WHERE filepath = ?", path)
        print("correct should be ", correct, " answer is ", ansr)
        if ansr == correct
            flash[:notice] = "Korrekt"
        else
            flash[:notice] = ("Fel, det skulle vara " + correct).to_s 
        end
        redirect "/game"
    end
end