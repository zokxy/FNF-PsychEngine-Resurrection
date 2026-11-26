package states.play;

import backend.Song.SwagSong;
import backend.AudioSync;
import flixel.sound.FlxSound;

class SongSync
{
	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;
	public var length:Float = 0;
	public var canResync:Bool = true;

	public var audioSync:AudioSync = new AudioSync();

	public function new() {}

	public function load(songData:SwagSong, bfVocals:String, dadVocals:String, rate:Float):Void
	{
		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			if (songData.needsVoices)
			{
				var playerFile = (bfVocals == null || bfVocals.length < 1) ? 'Player' : bfVocals;
				var playerVocals = Paths.voices(songData.song, playerFile);
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(songData.song));

				var oppFile = (dadVocals == null || dadVocals.length < 1) ? 'Opponent' : dadVocals;
				var oppVocals = Paths.voices(songData.song, oppFile);
				if (oppVocals != null && oppVocals.length > 0) opponentVocals.loadEmbedded(oppVocals);
			}
		}
		catch (e:Dynamic) {}

		#if FLX_PITCH
		vocals.pitch = rate;
		opponentVocals.pitch = rate;
		#end
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);

		inst = new FlxSound();
		try
		{
			inst.loadEmbedded(Paths.inst(songData.song));
		}
		catch (e:Dynamic) {}
		FlxG.sound.list.add(inst);
	}

	public function start(rate:Float, onComplete:Void->Void, startOnTime:Float, paused:Bool):Void
	{
		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		#if FLX_PITCH FlxG.sound.music.pitch = rate; #end
		FlxG.sound.music.onComplete = onComplete;
		length = FlxG.sound.music.length;

		setTime(Math.max(0, startOnTime - 500) + Conductor.offset, rate);

		if (paused) pause();
		audioSync.resetClock(Conductor.songPosition, FlxG.sound.music);
	}

	public function update(elapsed:Float, playbackRate:Float, isPlaying:Bool):Void
	{
		if (!isPlaying || !canResync)
		{
			Conductor.songPosition += elapsed * 1000 * playbackRate;
			return;
		}

		Conductor.songPosition = audioSync.update(
			Conductor.songPosition,
			FlxG.sound.music,
			vocals,
			opponentVocals,
			playbackRate,
			Conductor.offset
		);
	}

	public function setTime(time:Float, rate:Float):Void
	{
		var audioTime:Float = time - Conductor.offset;
		pause();

		FlxG.sound.music.time = audioTime;
		#if FLX_PITCH FlxG.sound.music.pitch = rate; #end
		FlxG.sound.music.play();

		syncVocal(vocals, audioTime, rate);
		syncVocal(opponentVocals, audioTime, rate);
		Conductor.songPosition = time;
		audioSync.resetClock(Conductor.songPosition, FlxG.sound.music);
	}

	public function resync(playbackRate:Float):Void
	{
		Conductor.songPosition = audioSync.forceResync(
			FlxG.sound.music,
			vocals,
			opponentVocals,
			playbackRate,
			Conductor.offset
		);
	}

	public function setPitch(rate:Float):Void
	{
		#if FLX_PITCH
		if (vocals != null) vocals.pitch = rate;
		if (opponentVocals != null) opponentVocals.pitch = rate;
		if (FlxG.sound.music != null) FlxG.sound.music.pitch = rate;
		#end
	}

	public function pause():Void
	{
		if (FlxG.sound.music != null) FlxG.sound.music.pause();
		if (vocals != null) vocals.pause();
		if (opponentVocals != null) opponentVocals.pause();
	}

	public function stop():Void
	{
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		if (vocals != null) vocals.stop();
		if (opponentVocals != null) opponentVocals.stop();
	}

	public function muteAndPause():Void
	{
		if (FlxG.sound.music != null) FlxG.sound.music.volume = 0;
		if (vocals != null)
		{
			vocals.volume = 0;
			vocals.pause();
		}
		if (opponentVocals != null)
		{
			opponentVocals.volume = 0;
			opponentVocals.pause();
		}
	}

	function syncVocal(voc:FlxSound, time:Float, rate:Float):Void
	{
		if (voc == null) return;
		if (time >= 0 && time < voc.length)
		{
			voc.time = time;
			#if FLX_PITCH voc.pitch = rate; #end
			voc.play();
		}
		else
			voc.pause();
	}
}