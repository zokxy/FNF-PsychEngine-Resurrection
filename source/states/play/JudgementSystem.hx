package states.play;

import backend.Rating;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSort;
import objects.Note;
import states.PlayState;

using StringTools;

class JudgementSystem extends FlxSpriteGroup
{
	public var ratingsData:Array<Rating> = Rating.loadDefault();

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var combo:Int = 0;
	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	public var ratingName:String = '?';
	public var ratingPercent:Float = 0;
	public var ratingFC:String = '';

	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;

	public var strumsBlocked:Array<Bool> = [];
	public var keysArray:Array<String> = ['note_left', 'note_down', 'note_up', 'note_right'];

	public function new()
	{
		super();
	}

	public function cachePopUps():Void
	{
		var uiFolder:String = (PlayState.stageUI != "normal") ? PlayState.uiPrefix + "UI/" : "";
		for (rating in ratingsData)
			Paths.image(uiFolder + rating.image + PlayState.uiPostfix);
		for (i in 0...10)
			Paths.image(uiFolder + 'num' + i + PlayState.uiPostfix);
	}

	public function popUpScore(note:Note, playbackRate:Float, cpuControlled:Bool, onSplash:Note->Void, onRecalc:Void->Void):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);

		if (!ClientPrefs.data.comboStacking && members.length > 0)
		{
			var i:Int = members.length - 1;
			while (i >= 0)
			{
				var spr = members[i];
				if (spr != null)
				{
					FlxTween.cancelTweensOf(spr);
					remove(spr, true);
					spr.destroy();
				}
				--i;
			}
		}

		var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if (!note.ratingDisabled) daRating.hits++;
		note.rating = daRating.name;

		if (daRating.noteSplash && !note.noteSplashData.disabled)
			onSplash(note);

		if (!cpuControlled)
		{
			songScore += daRating.score;
			if (!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				onRecalc();
			}
		}

		spawnPopUpSprites(daRating, playbackRate);
	}

	function spawnPopUpSprites(daRating:Rating, playbackRate:Float):Void
	{
		var placement:Float = FlxG.width * 0.35;
		var uiFolder:String = "";
		var antialias:Bool = ClientPrefs.data.antialiasing;
		if (PlayState.stageUI != "normal")
		{
			uiFolder = PlayState.uiPrefix + "UI/";
			antialias = !PlayState.isPixelStage;
		}

		var rating:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + daRating.image + PlayState.uiPostfix));
		rating.screenCenter();
		rating.x = placement - 40 + ClientPrefs.data.comboOffset[0];
		rating.y -= 60 + ClientPrefs.data.comboOffset[1];
		rating.acceleration.y = 550 * playbackRate * playbackRate;
		rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;
		rating.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
		rating.visible = (!ClientPrefs.data.hideHud && showRating);
		rating.antialiasing = antialias;

		if (!PlayState.isPixelStage)
			rating.setGraphicSize(Std.int(rating.width * 0.7));
		else
			rating.setGraphicSize(Std.int(rating.width * PlayState.daPixelZoom * 0.85));
		rating.updateHitbox();
		add(rating);

		FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate, {
			onComplete: function(_)
			{
				remove(rating, true);
				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.001 / playbackRate
		});

		var xThing:Float = 0;
		if (showComboNum)
		{
			var daLoop:Int = 0;
			var separatedScore:String = Std.string(combo).lpad('0', 3);
			for (i in 0...separatedScore.length)
			{
				var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + 'num' + Std.parseInt(separatedScore.charAt(i)) + PlayState.uiPostfix));
				numScore.screenCenter();
				numScore.x = placement + (43 * daLoop) - 90 + ClientPrefs.data.comboOffset[2];
				numScore.y += 80 - ClientPrefs.data.comboOffset[3];

				if (!PlayState.isPixelStage) numScore.setGraphicSize(Std.int(numScore.width * 0.5));
				else numScore.setGraphicSize(Std.int(numScore.width * PlayState.daPixelZoom));
				numScore.updateHitbox();

				numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
				numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
				numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
				numScore.visible = !ClientPrefs.data.hideHud;
				numScore.antialiasing = antialias;
				add(numScore);

				FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {
					onComplete: function(_)
					{
						remove(numScore, true);
						numScore.destroy();
					},
					startDelay: Conductor.crochet * 0.002 / playbackRate
				});

				daLoop++;
				if (numScore.x > xThing) xThing = numScore.x;
			}
		}

		if (showCombo)
		{
			var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + 'combo' + PlayState.uiPostfix));
			comboSpr.screenCenter();
			comboSpr.x = xThing > 0 ? xThing + 50 : placement + ClientPrefs.data.comboOffset[0];
			comboSpr.y += 60 - ClientPrefs.data.comboOffset[1];
			comboSpr.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
			comboSpr.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
			comboSpr.velocity.x += FlxG.random.int(1, 10) * playbackRate;
			comboSpr.visible = !ClientPrefs.data.hideHud;
			comboSpr.antialiasing = antialias;

			if (!PlayState.isPixelStage)
				comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
			else
				comboSpr.setGraphicSize(Std.int(comboSpr.width * PlayState.daPixelZoom * 0.85));
			comboSpr.updateHitbox();
			add(comboSpr);

			FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate, {
				onComplete: function(_)
				{
					remove(comboSpr, true);
					comboSpr.destroy();
				},
				startDelay: Conductor.crochet * 0.002 / playbackRate
			});
		}
	}

	public function recalculate():Void
	{
		ratingName = '?';
		if (totalPlayed == 0) return;

		ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
		var stuff = PlayState.ratingStuff;
		ratingName = stuff[stuff.length - 1][0];
		if (ratingPercent < 1)
		{
			for (i in 0...stuff.length - 1)
			{
				if (ratingPercent < stuff[i][1])
				{
					ratingName = stuff[i][0];
					break;
				}
			}
		}
	}

	public function calcFullCombo():Void
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = "";
		if (songMisses == 0)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0) ratingFC = 'SFC';
		}
		else
		{
			ratingFC = (songMisses < 10) ? 'SDCB' : 'Clear';
		}
	}

	public function formatScoreText(instakillOnMiss:Bool):String
	{
		var str:String = Language.getPhrase('rating_$ratingName', ratingName);
		if (totalPlayed != 0)
		{
			var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
			str += ' (${percent}%) - ' + Language.getPhrase(ratingFC);
		}

		if (!instakillOnMiss)
			return Language.getPhrase('score_text', 'Score: {1} | Misses: {2} | Rating: {3}', [songScore, songMisses, str]);
		return Language.getPhrase('score_text_instakill', 'Score: {1} | Rating: {2}', [songScore, str]);
	}

	public function findHitNote(notes:FlxTypedGroup<Note>, key:Int, onInvalidate:Note->Void, ?canHitNote:Note->Bool):Note
	{
		var inputNotes:Array<Note> = notes.members.filter(function(n:Note):Bool
		{
			var canHit:Bool = n != null && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit;
			if (canHit && canHitNote != null && !canHitNote(n)) return false;
			return canHit && !n.isSustainNote && n.noteData == key;
		});
		if (inputNotes.length == 0) return null;

		inputNotes.sort(sortHitNotes);
		var frontNote:Note = inputNotes[0];

		if (inputNotes.length > 1)
		{
			var doubleNote:Note = inputNotes[1];
			if (doubleNote.noteData == frontNote.noteData)
			{
				if (Math.abs(doubleNote.strumTime - frontNote.strumTime) < 1.0)
					onInvalidate(doubleNote);
				else if (doubleNote.strumTime < frontNote.strumTime)
					frontNote = doubleNote;
			}
		}
		return frontNote;
	}

	public function checkSustainHolds(notes:FlxTypedGroup<Note>, holdArray:Array<Bool>, guitarHeroSustains:Bool, onHit:Note->Void, ?canHitNote:Note->Bool):Void
	{
		if (notes.length <= 0) return;
		for (n in notes)
		{
			var canHit:Bool = (n != null && !strumsBlocked[n.noteData] && n.canBeHit
				&& n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

			if (canHit && canHitNote != null && !canHitNote(n)) continue;
			if (guitarHeroSustains)
				canHit = canHit && n.parent != null && n.parent.wasGoodHit;

			if (canHit && n.isSustainNote && holdArray[n.noteData])
				onHit(n);
		}
	}

	public static function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority) return 1;
		else if (!a.lowPriority && b.lowPriority) return -1;
		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note)
					if (key == noteKey) return i;
			}
		}
		return -1;
	}
}