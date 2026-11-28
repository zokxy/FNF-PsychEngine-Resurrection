package states.play;

import backend.Song.SwagSong;
import backend.AudioSync;
import flixel.sound.FlxSound;
import flash.media.Sound;

class SongSync
{
	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;
	public var voiceTracks:Array<FlxSound> = [];
	public var lineVoices:Array<FlxSound> = [];
	public var length:Float = 0;
	public var canResync:Bool = true;

	public var audioSync:AudioSync = new AudioSync();

	public function new() {}

	public function load(songData:SwagSong, bfVocals:String, dadVocals:String, rate:Float, ?extraCharVocals:Array<String>):Void
	{
		voiceTracks = [];
		lineVoices = [];
		var trackCache:Map<String, FlxSound> = new Map();

		function getOrLoadVoice(suffix:String, fallbackToMain:Bool):FlxSound
		{
			if (suffix == null) return null;
			var trimmed:String = suffix.trim();
			if (trimmed == '-' || trimmed.toLowerCase() == 'none') return null;

			var key:String = (trimmed.length > 0) ? trimmed.toLowerCase() : '__main__';
			if (trackCache.exists(key))
				return trackCache.get(key);

			var snd:Sound = null;
			try
			{
				snd = (trimmed.length > 0) ? Paths.voices(songData.song, trimmed) : Paths.voices(songData.song);
				if ((snd == null || snd.length <= 0) && fallbackToMain && trimmed.length > 0)
				{
					key = '__main__';
					if (trackCache.exists(key))
						return trackCache.get(key);
					snd = Paths.voices(songData.song);
				}
			}
			catch (e:Dynamic) {}

			if (snd == null || snd.length <= 0)
				return null;

			var track:FlxSound = new FlxSound();
			track.loadEmbedded(snd);
			#if FLX_PITCH
			track.pitch = rate;
			#end
			FlxG.sound.list.add(track);
			voiceTracks.push(track);
			trackCache.set(key, track);
			return track;
		}

		if (songData.needsVoices)
		{
			var playerFile:String = (bfVocals == null || bfVocals.length < 1) ? 'Player' : bfVocals;
			var oppFile:String = (dadVocals == null || dadVocals.length < 1) ? 'Opponent' : dadVocals;
			var lines = songData.strumLines;
			var lineCount:Int = (lines != null && lines.length >= 2) ? lines.length : 2;

			for (i in 0...lineCount)
			{
				var customSuffix:String = (lines != null && lines[i] != null) ? lines[i].vocalsSuffix : null;
				var track:FlxSound = null;

				if (customSuffix != null)
					track = getOrLoadVoice(customSuffix, i == 1);
				else if (i == 1)
					track = getOrLoadVoice(playerFile, true);
				else if (i == 0)
					track = getOrLoadVoice(oppFile, false);
				else if (extraCharVocals != null && i < extraCharVocals.length && extraCharVocals[i] != null && extraCharVocals[i].length > 0)
					track = getOrLoadVoice(extraCharVocals[i], false);

				lineVoices.push(track);
			}
		}

		vocals = (lineVoices.length > 1 && lineVoices[1] != null) ? lineVoices[1] : new FlxSound();
		opponentVocals = (lineVoices.length > 0 && lineVoices[0] != null) ? lineVoices[0] : new FlxSound();
		if (!FlxG.sound.list.members.contains(vocals)) FlxG.sound.list.add(vocals);
		if (!FlxG.sound.list.members.contains(opponentVocals)) FlxG.sound.list.add(opponentVocals);

		inst = new FlxSound();
		try
		{
			inst.loadEmbedded(Paths.inst(songData.song));
		}
		catch (e:Dynamic) {}
		FlxG.sound.list.add(inst);
	}

	public function getLineVoice(lineID:Int):FlxSound
	{
		if (lineID >= 0 && lineID < lineVoices.length && lineVoices[lineID] != null)
			return lineVoices[lineID];
		if (vocals != null && vocals.length > 0 && (opponentVocals == null || opponentVocals.length <= 0))
			return vocals;
		return null;
	}

	public function setLineVolume(lineID:Int, vol:Float):Void
	{
		var track:FlxSound = getLineVoice(lineID);
		if (track != null) track.volume = vol;
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
		audioSync.resetClock(FlxG.sound.music);
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
			voiceTracks,
			playbackRate,
			Conductor.offset
		);
	}

	public function setTime(time:Float, rate:Float):Void
	{
		var audioTime:Float = time - Conductor.offset;
		pause();

		FlxG.sound.music.play(true, audioTime);
		#if FLX_PITCH FlxG.sound.music.pitch = rate; #end

		for (track in voiceTracks)
			AudioSync.syncTrack(track, audioTime, rate);

		Conductor.songPosition = time;
		audioSync.resetClock(FlxG.sound.music);
	}

	public function resync(playbackRate:Float):Void
	{
		Conductor.songPosition = audioSync.forceResync(
			FlxG.sound.music,
			voiceTracks,
			playbackRate,
			Conductor.offset
		);
	}

	public function setPitch(rate:Float):Void
	{
		#if FLX_PITCH
		for (track in voiceTracks)
			if (track != null) track.pitch = rate;
		if (FlxG.sound.music != null) FlxG.sound.music.pitch = rate;
		#end
	}

	public function pause():Void
	{
		if (FlxG.sound.music != null) FlxG.sound.music.pause();
		for (track in voiceTracks)
			if (track != null) track.pause();
	}

	public function stop():Void
	{
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		for (track in voiceTracks)
			if (track != null) track.stop();
	}

	public function muteAndPause():Void
	{
		if (FlxG.sound.music != null) FlxG.sound.music.volume = 0;
		for (track in voiceTracks)
		{
			if (track != null)
			{
				track.volume = 0;
				track.pause();
			}
		}
	}
}