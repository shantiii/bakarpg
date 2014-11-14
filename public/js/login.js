function displayAlert(string) {
  alert(string);
}

function attemptRegister(username, password) {
  $.ajax({
    url: '/register',
    type: 'POST',
    data: JSON.stringify({ username: username, password: password }),
    statusCode: {
      403: function () {displayAlert( 'Already Logged In' );},
      400: function () {displayAlert( 'Invalid username or password'  );},
      409: function () {displayAlert( 'Username already taken!'  );},
      200: function () {displayAlert( 'Registration Successful!' );}
    }
  });
}

function attemptLogin(username, password) {
  $.ajax({
    url: '/login',
    type: 'POST',
    data: JSON.stringify({ username: username, password: password }),
    statusCode: {
      403: function () {displayAlert( 'Already Logged In' );},
      401: function () {displayAlert( 'Invalid username or password'  );},
      200: function () {displayAlert( 'Logged In!' );}
    }
  });
}

$('#modal-login-btn').click(function (evt) {
  evt.preventDefault();
  attemptLogin($('#modal-username-txt').val(), $('#modal-password-txt').val());
});

$('#modal-register-btn').click(function (evt) {
  evt.preventDefault();
  attemptRegister($('#modal-username-txt').val(), $('#modal-password-txt').val());
});
