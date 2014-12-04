function setHiddenTimeZone(hidTzId) {
	var localTime = new Date();
    var tz = (localTime.getTimezoneOffset())/60 * (-1);
    $("input[name='" + hidTzId + "']").val(tz);
    return true;
}

function navigate(route, confirm_msg) {
	submit = true;

	if (confirm_msg.length > 0)	{
		submit = confirm(confirm_msg);
	}

	if (submit) {
		document.location.href = route;
	}
}

function autoRefreshOn() {
	window.setTimeout('location.reload(true)', 60000);
}
