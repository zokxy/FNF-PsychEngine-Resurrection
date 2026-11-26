package states.play;

import backend.Song.SwagSection;
import backend.Song.SwagSong;
import backend.Song.StrumLineData;
import flixel.FlxBasic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSort;
import objects.Character;
import objects.Note;
import objects.NoteSplash;
import objects.StrumNote;
import states.PlayState;

class NoteManager extends FlxTypedGroup<FlxBasic>
{
	public var strumLines:Array<StrumLine> = [];
	public var opponentLine:StrumLine;
	public var playerLine:StrumLine;

	public var strumLineNotes:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var notes:FlxTypedGroup<Note> = new FlxTypedGroup<Note>();
	public var unspawnNotes:Array<Note> = [];
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();

	public var spawnTime:Float = 2000;
	public var skipArrowStartTween:Bool = false;
	public var totalColumns:Int = 4;

	public function new()
	{
		super();

		opponentLine = addStrumLine(false);
		playerLine = addStrumLine(true);

		add(strumLineNotes);
		add(notes);
		add(grpNoteSplashes);
	}

	public function addStrumLine(isPlayer:Bool = false, ?characters:Array<Character>, ?x:Null<Float>, ?y:Null<Float>, keysCount:Int = 4, scaleMult:Float = 1):StrumLine
	{
		var line = new StrumLine(strumLines.length, isPlayer, keysCount);
		line.characters = characters;
		line.customX = x;
		line.customY = y;
		line.scaleMult = scaleMult;
		strumLines.push(line);
		return line;
	}

	public function loadStrumLines(dataList:Array<StrumLineData>, resolveChar:(String, Int)->Character):Void
	{
		if (dataList == null || dataList.length == 0) return;

		for (i in 0...dataList.length)
		{
			var data:StrumLineData = dataList[i];
			var line:StrumLine = (i < strumLines.length) ? strumLines[i] : addStrumLine(data.type == 1);
			line.applyData(data);

			if (data.characters != null && data.characters.length > 0)
			{
				var chars:Array<Character> = [];
				for (name in data.characters)
				{
					var c:Character = resolveChar(name, data.type);
					if (c != null && !chars.contains(c)) chars.push(c);
				}
				if (chars.length > 0) line.characters = chars;
			}
		}
	}

	public inline function getStrumLine(note:Note):StrumLine
	{
		var id:Int = note.strumLineID;
		if (id < 0 || id >= strumLines.length)
			id = note.mustPress ? 1 : 0;
		return strumLines[id];
	}

	public inline function isNoteControllable(note:Note):Bool
	{
		var line:StrumLine = getStrumLine(note);
		return line != null && line.isPlayer && !line.cpuControlled;
	}

	public function getMaxPlayerKeys():Int
	{
		var maxKeys:Int = totalColumns;
		for (line in strumLines)
			if (line.isPlayer && line.keysCount > maxKeys)
				maxKeys = line.keysCount;
		return maxKeys;
	}

	public function generateStaticArrows(player:Int, isStoryMode:Bool):Void
	{
		var line = strumLines[player];
		if (line != null)
			line.generate(strumLineNotes, isStoryMode, skipArrowStartTween);
	}

	public function generateAllArrows(isStoryMode:Bool):Void
	{
		for (line in strumLines)
			line.generate(strumLineNotes, isStoryMode, skipArrowStartTween);
	}

	public function layoutLines(?scale:Null<Float>, margin:Float = 32):Void
	{
		var active:Array<StrumLine> = [for (l in strumLines) if (l.visible) l];
		if (active.length <= 0) return;

		var autoScale:Float = scale != null ? scale : (active.length > 2 ? Math.min(1.0, (FlxG.width - margin * (active.length + 1)) / (active.length * totalColumns * Note.swagWidth)) : 1.0);
		var totalLinesWidth:Float = 0;
		for (l in active) totalLinesWidth += l.keysCount * l.spacing * autoScale;

		var gap:Float = (FlxG.width - totalLinesWidth) / (active.length + 1);
		var curX:Float = gap;
		for (l in active)
		{
			var y:Float = l.customY != null ? l.customY : (l.isDownScroll() ? FlxG.height - 150 : 50);
			l.setPosition(curX, y, null, autoScale);
			curX += (l.keysCount * l.spacing * autoScale) + gap;
		}
	}

	public function assignNotesToLine(lineID:Int, filter:Note->Bool):Void
	{
		if (lineID < 0 || lineID >= strumLines.length) return;
		var line:StrumLine = strumLines[lineID];
		for (n in unspawnNotes)
		{
			if (filter(n))
			{
				n.strumLineID = lineID;
				n.mustPress = line.isPlayer;
			}
		}
		for (n in notes.members)
		{
			if (n != null && filter(n))
			{
				n.strumLineID = lineID;
				n.mustPress = line.isPlayer;
			}
		}
	}

	public function loadChart(songData:SwagSong, playbackRate:Float):Array<String>
	{
		var noteTypes:Array<String> = [];
		var oldNote:Note = null;
		var sectionsData:Array<SwagSection> = songData.notes;
		var ghostNotesCaught:Int = 0;
		var daBpm:Float = Conductor.bpm;

		for (section in sectionsData)
		{
			if (section.changeBPM != null && section.changeBPM && section.bpm != null && daBpm != section.bpm)
				daBpm = section.bpm;

			for (i in 0...section.sectionNotes.length)
			{
				final songNotes:Array<Dynamic> = section.sectionNotes[i];
				var noteTime:Float = songNotes[0];
				var rawData:Int = Std.int(songNotes[1]);
				var noteColumn:Int = rawData % totalColumns;
				var holdLength:Float = songNotes[2];
				var noteType:String = !Std.isOfType(songNotes[3], String) ? Note.defaultNoteTypes[songNotes[3]] : songNotes[3];
				if (Math.isNaN(holdLength)) holdLength = 0.0;

				var lineID:Int = (rawData < totalColumns) ? 1 : (rawData < totalColumns * 2 ? 0 : Std.int(rawData / totalColumns));
				while (strumLines.length <= lineID)
					addStrumLine(false);

				var line:StrumLine = strumLines[lineID];
				var gottaHitNote:Bool = line.isPlayer;

				if (i != 0)
				{
					for (evilNote in unspawnNotes)
					{
						var matches:Bool = (noteColumn == evilNote.noteData && lineID == evilNote.strumLineID && evilNote.noteType == noteType);
						if (matches && Math.abs(noteTime - evilNote.strumTime) < FlxMath.EPSILON)
						{
							if (evilNote.tail.length > 0)
							{
								for (tail in evilNote.tail)
								{
									tail.destroy();
									unspawnNotes.remove(tail);
								}
							}
							evilNote.destroy();
							unspawnNotes.remove(evilNote);
							ghostNotesCaught++;
						}
					}
				}

				var swagNote:Note = new Note(noteTime, noteColumn, oldNote);
				var isAlt:Bool = section.altAnim && !gottaHitNote;
				swagNote.gfNote = (section.gfSection && gottaHitNote == section.mustHitSection);
				swagNote.animSuffix = isAlt ? "-alt" : "";
				swagNote.mustPress = gottaHitNote;
				swagNote.strumLineID = lineID;
				swagNote.sustainLength = holdLength;
				swagNote.noteType = noteType;
				swagNote.scrollFactor.set();
				unspawnNotes.push(swagNote);

				var curStepCrochet:Float = 60 / daBpm * 1000 / 4.0;
				final roundSus:Int = Math.round(swagNote.sustainLength / curStepCrochet);
				if (roundSus > 0)
				{
					for (susNote in 0...roundSus)
					{
						oldNote = unspawnNotes[unspawnNotes.length - 1];

						var sustainNote:Note = new Note(noteTime + (curStepCrochet * susNote), noteColumn, oldNote, true);
						sustainNote.animSuffix = swagNote.animSuffix;
						sustainNote.mustPress = swagNote.mustPress;
						sustainNote.strumLineID = lineID;
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						swagNote.tail.push(sustainNote);

						sustainNote.correctionOffset = swagNote.height / 2;
						if (!PlayState.isPixelStage)
						{
							if (oldNote.isSustainNote)
							{
								oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
								oldNote.scale.y /= playbackRate;
								oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
							}
							if (line.isDownScroll())
								sustainNote.correctionOffset = 0;
						}
						else if (oldNote.isSustainNote)
						{
							oldNote.scale.y /= playbackRate;
							oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
						}

						applyNoteOffset(sustainNote, lineID, noteColumn);
					}
				}

				applyNoteOffset(swagNote, lineID, noteColumn);

				if (!noteTypes.contains(swagNote.noteType))
					noteTypes.push(swagNote.noteType);

				oldNote = swagNote;
			}
		}

		trace('["${songData.song.toUpperCase()}" CHART INFO]: Ghost Notes Cleared: $ghostNotesCaught');
		unspawnNotes.sort(PlayState.sortByTime);
		return noteTypes;
	}

	inline function applyNoteOffset(note:Note, lineID:Int, column:Int):Void
	{
		if (lineID == 1)
			note.x += FlxG.width / 2;
		else if (lineID == 0 && ClientPrefs.data.middleScroll)
		{
			note.x += 310;
			if (column > 1) note.x += FlxG.width / 2 + 25;
		}
	}

	public function resizeByRatio(ratio:Float):Void
	{
		for (note in notes.members)
			if (note != null) note.resizeByRatio(ratio);
		for (note in unspawnNotes)
			if (note != null) note.resizeByRatio(ratio);
	}

	public function spawnUpcoming(songPos:Float, songSpeed:Float, playbackRate:Float, onSpawn:Note->Void):Void
	{
		if (unspawnNotes[0] == null) return;

		var time:Float = spawnTime * playbackRate;
		if (songSpeed < 1) time /= songSpeed;
		if (unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

		while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - songPos < time)
		{
			var dunceNote:Note = unspawnNotes.shift();
			notes.insert(0, dunceNote);
			dunceNote.spawned = true;
			onSpawn(dunceNote);
		}
	}

	function syncNoteScale(note:Note, line:StrumLine, strum:StrumNote):Void
	{
		var ratio:Float = line.scaleMult / note.lineScale;
		note.lineScale = line.scaleMult;

		note.scale.x *= ratio;
		if (!note.isSustainNote)
			note.scale.y *= ratio;
		else
			note.correctionOffset *= ratio;

		note.updateHitbox();
		note.offsetX = (strum.width - note.width) / 2;
	}

	public function updateNotes(
		startedCountdown:Bool,
		fakeCrochet:Float,
		songSpeed:Float,
		playbackRate:Float,
		noteKillOffset:Float,
		cpuControlled:Bool,
		endingSong:Bool,
		onGoodHit:Note->Void,
		onOppHit:Note->Void,
		onMiss:Note->Void
	):Void
	{
		if (notes.length <= 0) return;

		if (!startedCountdown)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				daNote.canBeHit = false;
				daNote.wasGoodHit = false;
			});
			return;
		}

		var i:Int = 0;
		while (i < notes.length)
		{
			var daNote:Note = notes.members[i];
			if (daNote == null)
			{
				i++;
				continue;
			}

			var line:StrumLine = getStrumLine(daNote);
			var strum:StrumNote = line != null ? line.getStrum(daNote.noteData) : null;
			if (strum == null)
			{
				i++;
				continue;
			}
			if (!line.visible) daNote.visible = false;
			if (daNote.lineScale != line.scaleMult)
				syncNoteScale(daNote, line, strum);
			var lineSpeed:Float = (line.scrollSpeed != null) ? line.scrollSpeed : songSpeed;
			daNote.followStrumNote(strum, fakeCrochet, lineSpeed / playbackRate);

			var isBot:Bool = cpuControlled || line.cpuControlled;
			if (line.isPlayer)
			{
				if (isBot && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
					onGoodHit(daNote);
			}
			else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
				onOppHit(daNote);

			if (daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumNote(strum);

			if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
			{
				if (line.isPlayer && !isBot && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
					onMiss(daNote);

				daNote.active = daNote.visible = false;
				invalidate(daNote);
			}
			if (daNote.exists) i++;
		}
	}

	public function resetPlayerAnims():Void
	{
		for (line in strumLines)
			if (line.isPlayer) line.resetAnims();
	}

	public function clearBefore(time:Float):Void
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = unspawnNotes[i];
			if (daNote != null && daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				daNote.kill();
				unspawnNotes.splice(i, 1);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = notes.members[i];
			if (daNote != null && daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				invalidate(daNote);
			}
			--i;
		}
	}

	public function killAll():Void
	{
		var i:Int = notes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = notes.members[i];
			if (daNote != null)
			{
				daNote.active = false;
				daNote.visible = false;
				invalidate(daNote);
			}
			--i;
		}
		for (n in unspawnNotes)
			if (n != null) n.destroy();
		unspawnNotes = [];
	}

	public function invalidate(note:Note):Void
	{
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	public function sortByY(downScroll:Bool):Void
	{
		notes.sort(FlxSort.byY, downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
	}

	public function precacheSplash():Void
	{
		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = 0.000001;
	}

	public function spawnSplashOnNote(note:Note):Void
	{
		if (note == null) return;
		var line:StrumLine = getStrumLine(note);
		if (line == null || !line.visible) return;
		var strum:StrumNote = line.getStrum(note.noteData);
		if (strum != null)
			spawnSplash(strum.x, strum.y, note.noteData, note, strum, line.scaleMult);
	}

	public function spawnSplash(x:Float = 0, y:Float = 0, ?data:Int = 0, ?note:Note, ?strum:StrumNote, lineScale:Float = 1):Void
	{
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		if (splash.lineScale != 1)
		{
			splash.scale.x /= splash.lineScale;
			splash.scale.y /= splash.lineScale;
			splash.lineScale = 1;
		}

		splash.babyArrow = strum;
		splash.spawnSplashNote(x, y, data, note);

		if (lineScale != 1)
		{
			splash.centerOrigin();
			splash.scale.x *= lineScale;
			splash.scale.y *= lineScale;
			splash.lineScale = lineScale;
			if (strum != null)
			{
				splash.offset.x += (strum.width / lineScale - strum.width) / 2;
				splash.offset.y += (strum.height / lineScale - strum.height) / 2;
			}
		}
	}

	public function strumPlayAnim(isDad:Bool, id:Int, time:Float, ?lineID:Int):Void
	{
		var line:StrumLine = (lineID != null && strumLines[lineID] != null) ? strumLines[lineID] : (isDad ? opponentLine : playerLine);
		line.playAnim(id, time);
	}
}