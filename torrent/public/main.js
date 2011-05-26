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

function Torrents(opt)
{
	cO(this, opt)
	this.initialize()
}

Torrents.prototype = {
	initialize: function()
	{
		this.columns = [];
		this.columns.push(null)
		this.columns.push(null)
		this.columns.push(null)
		this.columns.push(["Name", "26%"])
		this.columns.push(["Status", "12%"])
		this.columns.push(["%", "6%"])
		this.columns.push(["Size", "8%"])
		this.columns.push(["DL", "8%"])
		this.columns.push(["UL", "8%"])
		this.columns.push(["S", "4%"])
		this.columns.push(["L", "4%"])
		this.columns.push(["ETA", "4%"])
		this.columns.push(["Down", "8%"])
		this.columns.push(["Up", "8%"])
		this.wrapperDiv = ge(this.id);
		
		this.mainTable = ce('table');
		var thead = ce('thead');
		this.mainBody = ce('tbody');
		var tr = ce('tr');
		
		var th = ce('th');
		th.style.width = "4%"
		ae(th, ct(""));
		ae(tr, th);
		
		for (var x in this.columns) 
		{
			if(this.columns[x])
			{	
				var th = ce('th');
				if(this.columns[x][1])
					th.style.width = this.columns[x][1]
				ae(th, ct(this.columns[x][0]));
				ae(tr, th);
			}
		}
		ae(thead, tr);
		ae(this.mainTable, thead);
		ae(this.mainTable, this.mainBody);
		ae(this.wrapperDiv, this.mainTable);
		this.update();
		$(this).oneTime("1s", function() {
			this.update();
		});
		this.startTimer();
	},
	update: function()
	{
		this.mainBody.innerHTML = "";		
		
		for (var x in this.torrents)
		{
			var tr = ce('tr');
			var td = ce('td');
			td.style.textAlign = 'right';
			td.style.width = '4%';
			if (this.torrents[x][0] != "")
			{
				var a = ce('a')
				a.onclick = function(x) { $.ajax({ url: '/torrent/' + this.torrents[x][0] + '/start', context: this, success: function(data){}}); }.bind(this, x)
				a.href = 'javascript:;'
				ae(a, ct("S"))
				ae(td, a)
				ae(td, ct(" "))
			
				var a = ce('a')
				a.onclick = function(x) { $.ajax({ url: '/torrent/' + this.torrents[x][0] + '/pause', context: this, success: function(data){}}); }.bind(this, x)
				a.href = 'javascript:;'
				ae(a, ct("P"))
				ae(td, a)
				ae(td, ct(" "))
			}
			ae(tr, td);

			for (var y in this.torrents[x])
			{
				var td = ce('td');
				if(this.columns[y])
					td.style.width = this.columns[y][1]
				if (y == 3) {
					var a = ce('a')
					a.href = '/torrent/' + this.torrents[x][0]
					a.title = this.torrents[x][2]
					a.className = 'tooltip'
					ae(a, ct(this.torrents[x][y]))
					ae(td, a)
				}
				else if (y == 1 || y == 0 || y == 2) {
					continue;
				}
				else
					ae(td, ct(this.torrents[x][y]));
				ae(tr, td);
			}
			ae(this.mainBody, tr);
		}
		$(".tooltip").tipTip({maxWidth: "auto", defaultPosition: 'top'});
		$.ajax({ url: "active_torrents.json", dataType: 'json', context: this, success: function(data){
		        this.torrents = data
		      }});
	},
	startTimer: function()
	{
		$(this).everyTime("2s", "torrents", function() {
			this.update();
		});
	}
}