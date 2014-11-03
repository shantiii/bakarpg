var localUserlist = [];

function updateUsers() {
  var userlistHTML = [];
  for(var user in localUserlist) {
    userlistHTML.push('<li>'+localUserlist[user]+'</li>');
  }
  $('#user-list').html(userlistHTML.join(""));
}

function addEntry(queue, message) {
  $('#main-chat-ul').append("<li>" + message + "</li>");
  console.log("["+queue+"]: " + message);
}

function serverNotice(message) {
  addEntry("serverNotice", "<i>"+message+"</i>");
}

function localNotice(message) {
  addEntry("localNotice", "<u>"+message+"</u>");
}

function chatMessage(nick, message) {
  addEntry("message", "<b>&lt;" + nick + "&gt;</b>&nbsp;" + message);
}

function emote(nick, message) {
  addEntry("message", nick + message);
}

function proc_error(evt) {
  localNotice("Error with chat connection!");
  console.log("WebSocket error!");
  console.log(evt);
}

function proc_open(evt) {
  localNotice("Connected to chat server!");
  console.log("WebSocket opened!");
}

function proc_close(evt) {
  localNotice("WebSocket closed!");
  console.log("WebSocket closed!");
}
var chatNick = undefined;
function proc_message(evt) {
  try {
    var msg = JSON.parse(evt.data);
    switch(msg.type) {
      case "userlist":
        localUserlist = msg.nicks;
        updateUsers(localUserlist);
        break;
      case "id":
        chatNick = msg.nick;
        serverNotice("Server recognizes you as " + msg.nick + ".");
        break;
      case "join":
        if (msg.nick == chatNick) {
          serverNotice("You have joined the room.");
        } else {
          serverNotice(msg.nick + " has joined the room.");
          localUserlist.push(msg.nick);
          updateUsers(localUserlist);
        }
        break;
      case "leave":
        serverNotice(msg.nick + " has left the room.");
        var nickIndex = localUserlist.indexOf(msg.nick);
        if (nickIndex != -1) {
          localUserlist.splice(nickIndex, 1);
          updateUsers(localUserlist);
        }
        break;
      case "rename":
        serverNotice(msg.old + " is now known as " + msg.new);
        var nickIndex = localUserlist.indexOf(msg.old);
        if (nickIndex != -1) {
          localUserlist[nickIndex] = msg.new;
          updateUsers(localUserlist);
        }
        break;
      case "error":
        serverNotice(msg.message);
        break;
      case "chat":
        chatMessage(msg.nick, msg.message);
        break;
      case "emote":
        emote(msg.nick, msg.message);
        break;
      default:
        console.log("Unknown message type.");
        break;
    }
  } catch(e) {
    console.log("Server sent bad message: " + e);
  }
}
var chatSocket = null;

function initWebSocket() {
  var socket = new WebSocket(getServerConfig().socketUri);
  socket.onopen = function (evt) {proc_open(evt);}
  socket.onclose = function (evt) {proc_close(evt);}
  socket.onerror = function (evt) {proc_error(evt);}
  socket.onmessage = function (evt) {proc_message(evt);}
  chatSocket = socket;
}

function requestUserlist() {
  chatSocket.send(JSON.stringify({type:"userlist"}));
}

function sendChatMessage() {
  var message = $("#chat-textbox").val();
  if (message === "") {
    return;
  }
  var nickMatches = (/^\/nick\s+(.+?)\s*$/).exec(message);
  if (nickMatches != null) {
    chatSocket.send(JSON.stringify({type:"nick", nick: nickMatches[1]}));
  } else {
    chatSocket.send(JSON.stringify({type:"chat", message: message}));
  }
  $("#chat-textbox").val("");
}

window.addEventListener("load", initWebSocket(), false);
