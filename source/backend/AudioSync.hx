package backend;

import flixel.sound.FlxSound;
import haxe.Timer;

class AudioSync
{
	public var softDeadzoneMs:Float = 3.0;
	public var softCorrectionRate:Float = 10.0;
	public var hardSnapMs:Float = 35.0;
	public var vocalsDriftMs:Float = 25.0;
	public var resyncCooldown:Float = 0.4;

	var lastStamp:Float = -1;
	var lastMusicTime:Float = -1;
	var lastResyncStamp:Float = -1;
	var pendingDrift:Float = 0;

	public function new() {}

	public function resetClock(?music:FlxSound):Void
	{
		lastStamp = Timer.stamp();
		lastMusicTime = music != null ? music.time : -1;
		lastResyncStamp = -1;
		pendingDrift = 0;
	}

	public function update(songPosition:Float, music:FlxSound, voiceTracks:Array<FlxSound>, playbackRate:Float, offset:Float = 0):Float
	{
		if (music == null || !music.playing)
		{
			lastStamp = Timer.stamp();
			pendingDrift = 0;
			return songPosition;
		}

		var now:Float = Timer.stamp();
		var dt:Float = lastStamp > 0 ? (now - lastStamp) : 0;
		lastStamp = now;

		var spike:Bool = dt < 0 || dt > 0.1;
		if (!spike)
		{
			songPosition += dt * 1000.0 * playbackRate;
			if (pendingDrift != 0)
			{
				var nextDrift:Float = CoolUtil.expLerp(pendingDrift, 0, softCorrectionRate, dt);
				songPosition += pendingDrift - nextDrift;
				pendingDrift = Math.abs(nextDrift) < 0.05 ? 0 : nextDrift;
			}
		}

		var musicTime:Float = music.time;
		var targetPos:Float = musicTime + offset;

		if (spike || musicTime != lastMusicTime)
		{
			lastMusicTime = musicTime;
			var drift:Float = targetPos - songPosition;
			var absDrift:Float = Math.abs(drift);

			if (spike || absDrift >= hardSnapMs)
			{
				songPosition = targetPos;
				pendingDrift = 0;
				checkVocals(music, voiceTracks, playbackRate, now, true);
			}
			else if (absDrift >= softDeadzoneMs)
			{
				pendingDrift = drift;
				checkVocals(music, voiceTracks, playbackRate, now, false);
			}
			else
			{
				pendingDrift = 0;
				checkVocals(music, voiceTracks, playbackRate, now, false);
			}
		}

		return songPosition;
	}

	public function checkVocals(music:FlxSound, voiceTracks:Array<FlxSound>, playbackRate:Float, now:Float, force:Bool = false):Bool
	{
		if (voiceTracks == null || voiceTracks.length == 0)
			return false;
		if (!force && now - lastResyncStamp < resyncCooldown)
			return false;

		var musicTime:Float = music.time;
		var synced:Bool = false;

		for (track in voiceTracks)
		{
			if (track != null && track.length > 0 && musicTime < track.length - 50)
			{
				if (force || !track.playing || Math.abs(track.time - musicTime) > vocalsDriftMs)
				{
					syncTrack(track, musicTime, playbackRate);
					synced = true;
				}
			}
		}

		if (synced)
			lastResyncStamp = now;
		return synced;
	}

	public function forceResync(music:FlxSound, voiceTracks:Array<FlxSound>, playbackRate:Float, offset:Float = 0):Float
	{
		if (music == null) return 0;

		if (!music.playing)
			music.play();
		#if FLX_PITCH
		music.pitch = playbackRate;
		#end

		var musicTime:Float = music.time;
		if (voiceTracks != null)
		{
			for (track in voiceTracks)
				syncTrack(track, musicTime, playbackRate);
		}

		lastStamp = Timer.stamp();
		lastMusicTime = musicTime;
		lastResyncStamp = lastStamp;
		pendingDrift = 0;
		return musicTime + offset;
	}

	public static function syncTrack(track:FlxSound, targetTime:Float, playbackRate:Float):Void
	{
		if (track == null || track.length <= 0) return;

		if (targetTime < 0 || targetTime >= track.length)
		{
			if (track.playing) track.pause();
			return;
		}

		track.play(true, targetTime);
		#if FLX_PITCH
		track.pitch = playbackRate;
		#end
	}
}