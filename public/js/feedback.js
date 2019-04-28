
function like_clicked(id) {
  console.log("Toggle pushed!");
  var $likeSpan = $('#feedback-like-' + id);
  var votedIcon = '<i class="fa fa-star"></i>'
  var unvotedIcon = '<i class="fa fa-star-o"></i>'
  var haveVoted = $likeSpan.hasClass('success');
  var numLikes = parseInt($likeSpan.get(0).innerText);
  if (haveVoted) {
    $.ajax({
      url:'/feedback/'+id+'/like',
      type:'POST',
      success: function() {
        $likeSpan.get(0).innerHTML = (numLikes - 1) + unvotedIcon;
        $likeSpan.removeClass("success");
      }
    });
  } else {
    $.ajax({
      url:'/feedback/'+id+'/like',
      type:'POST',
      success: function() {
        $likeSpan.get(0).innerHTML = (numLikes + 1) + votedIcon;
        $likeSpan.addClass("success");
      }
    });
  }
}

function post_feedback (title, description, skip_redirect) {
  $.ajax({
    url: '/feedback',
  type: 'POST',
  data: JSON.stringify({title: title, description: description}),
  success: function (data) {
    console.log("post succeeded!");
    console.log(data);
    if (skip_redirect) {
      window.location.replace("/feedback");
    }
  }
  });
}
