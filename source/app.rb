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

    post "/manage/add-person" do
        uploadDir = "./public/img/"

        if params['fileupload'] && params['fileupload']["tempfile"] && params['fileupload']["filename"]
            file = params['fileupload']
            filename = (db.execute("SELECT id FROM people ORDER BY id DESC LIMIT 1").first["id"]+1).to_s+".png"
            tempfile = file["tempfile"]
            name = params['name']

            filepath = File.join(uploadDir, filename)
            relpath = "/img/#{filename}"

            FileUtils.cp(tempfile.path, filepath)


            print("Adding #{filename} as #{name} at #{relpath}\n")
            db.execute("INSERT INTO people (name,filepath) VALUES (?,?)", [name, relpath])
            redirect '/manage'
        else
            print("No file was found\n")
            flash[:notice] = "Failed to upload file: No file found"
            redirect '/manage'
        end
    end

    get '/manager/default' do
        $type = "default"
        load "./db/default.rb"
        flash[:success] = "Database Defaulted Successfully"
        redirect '/manage'
    end

    get '/manager/delete-all' do
        db.execute("DROP TABLE IF EXISTS people")
        redirect '/manage'
    end

    get '/' do
        ##stuff
        # erb: (page)
        redirect "/index"
    end

    get '/game/:id' do |id|
        result = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", ["people"])
        if result.empty?
          redirect "/manage"
        else
            @people_db = db.execute("SELECT * FROM people")
            @game_id = id
            erb :game
        end
    end

    get '/index' do
        erb :index
    end

    get '/manage' do
        result = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", ["people"])
        if result.empty?
          @db_content = "empty"
        else
            @db_content = db.execute("SELECT * FROM people")
        end
        erb :manage
    end

    post "/game/1" do
        ansr = params['answer']
        imgid = params['img_id']
        print "answer is #{ansr} and imgid is #{imgid}"
        correct = db.execute("SELECT name FROM people WHERE id = ?", imgid).first["name"]
        print("correct should be ", correct, " answer is ", ansr)
        if ansr == correct
            flash[:notice] = "Korrekt"
        else
            flash[:notice] = "Fel, det skulle vara #{correct}"
        end
        redirect "/game/1"
    end
end