ge = function(z){return document.getElementById(z)}
ct = function(z){return document.createTextNode(z)}
cO = function(d, s){for(var p in s) if(s[p] !== null && typeof s[p] == 'object' && s[p].length)d[p]=s[p].slice(0);else d[p]=s[p] }
ce = function(z, p, c){var r = document.createElement(z); if(p) cOr(r, p); if(c) ae(r, c); return r }
ae = function(z,y){return z.appendChild(y)}
cOr = function(d, s) {for(var p in s){if(typeof s[p] == 'object'){ if(s[p].length) d[p] = s[p].slice(0); else { if(!d[p]) d[p] = {}; cOr(d[p], s[p]); } } else d[p] = s[p]; } }
$A = function(a)
{
	var r = [];
	for (var i = 0, len = a.length; i < len; ++i)
		r.push(a[i]);
	return r;
}

if(!Function.prototype.bind)
{
	Function.prototype.bind = function()
	{
		var
			__method = this,
			args = $A(arguments),
			object = args.shift();

		return function()
		{
			return __method.apply(object, args.concat($A(arguments)))
		};
	}
}

function WebIrc(opt)
{
	cO(this, opt)
	this.initialize()
}

WebIrc.prototype = {
	initialize: function()
	{
		this.wrapperDiv = ge(this.id);
		
		this.update();
		$(this).oneTime("1s", function() {
			this.update();
		});
		this.startTimer();
	},
	update: function()
	{
		$.ajax({ url: "lines.json", dataType: 'json', context: this, success: function(data){
	        this.lines = data
	      }});
		this.wrapperDiv.innerHTML = "";		
		
		for (var x in this.lines)
		{
			var div = ce('div');
			ae(div, ct('<'+this.lines[x][0] +'>'));
			ae(div, ct(' '+this.lines[x][2]));
			ae(this.wrapperDiv, div);
		}
	},
	startTimer: function()
	{
		$(this).everyTime("1s", "ircupdate", function() {
			this.update();
		});
	}
}