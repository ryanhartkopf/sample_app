'use strict';

// setup
var express = require('express');
var app = express();
var mongoose = require('mongoose');
var morgan = require('morgan');
var bodyParser = require('body-parser');
var methodOverride = require('method-override');

const PORT = 8080;
const HOST = '0.0.0.0';
const DB_HOST = process.env.DB_HOST || "localhost";

// configuration
mongoose.connect('mongodb://' + DB_HOST + '/todo');

app.use(express.static(__dirname + '/public'));
app.use(morgan('dev'));
app.use(bodyParser.urlencoded({'extended':'true'}));
app.use(bodyParser.json());
app.use(bodyParser.json({ type: 'application/vnd.api+json' }));
app.use(methodOverride());

// define model
var Todo = mongoose.model('Todo', {
  text : String
});

// routes
  // api
  // get all todos
  app.get('/api/todos', function(req, res) {

    // if there is an error retrieving, send the error
    Todo.find(function(err, todos) {
      if (err)
        res.send(err)

      // return all todos in JSON format
      res.json(todos);
    });
  });

  // create a todo
  app.post('/api/todos', function(req, res) {

    // Create a todo based on body of request from Angular
    Todo.create({
      text : req.body.text,
      done : false
    }, function(err, todo) {
      if (err)
        res.send(err);

      // return all todos after adding one
      Todo.find(function(err, todos) {
        if (err)
          res.send(err);
        res.json(todos);
      });
    });
  });

  // delete a todo
  app.delete('/api/todos/:todo_id', function(req, res) {

    // Delete a todo based on ID
    Todo.remove({
      _id : req.params.todo_id
    }, function(err, todo) {
      if (err)
        res.send(err);

      // return all todos after deleting one
      Todo.find(function(err, todos) {
        if(err)
          res.send(err);
        res.json(todos);
      });
    });
  });

  // application
  app.get('*', function(req, res) {
    res.sendFile(__dirname + '/public/index.html');
  });

// listen
app.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);
