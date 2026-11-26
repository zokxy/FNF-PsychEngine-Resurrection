package backend;

import flixel.sound.FlxSound;
import haxe.Timer;

class AudioSync
{
	public var softDeadzoneMs:Float = 3.0;
	public var softCorrectionFactor:Float = 0.35;
	public var hardSnapMs:Float = 35.0;
	public var vocalsDriftMs:Float = 25.0;
	public var resyncCooldown:Float = 0.4;

	var lastStamp:Float = -1;
	var lastMusicTime:Float = -1;
	var lastResyncStamp:Float = -1;

	public function new() {}

	public function resetClock(songPosition:Float, ?music:FlxSound):Void
	{
		lastStamp = Timer.stamp();
		lastMusicTime = music != null ? music.time : -1;
		lastResyncStamp = -1;
	}

	public function update(songPosition:Float, music:FlxSound, vocals:FlxSound, opponentVocals:FlxSound, playbackRate:Float, offset:Float = 0):Float
	{
		if (music == null || !music.playing)
		{
			lastStamp = Timer.stamp();
			return songPosition;
		}

		var now:Float = Timer.stamp();
		var dt:Float = lastStamp > 0 ? (now - lastStamp) : 0;
		lastStamp = now;

		var spike:Bool = dt < 0 || dt > 0.1;
		if (!spike)
			songPosition += dt * 1000.0 * playbackRate;

		var musicTime:Float = music.time;
		var targetPos:Float = musicTime + offset;

		if (spike || musicTime != lastMusicTime)
		{
			lastMusicTime = musicTime;
			var drift:Float = targetPos - songPosition;
			var absDrift:Float = Math.abs(drift);

			if (spike || absDrift >= hardSnapMs * playbackRate)
			{
				songPosition = targetPos;
				checkVocals(music, vocals, opponentVocals, playbackRate, now, true);
			}
			else if (absDrift >= softDeadzoneMs)
			{
				songPosition += drift * softCorrectionFactor;
				checkVocals(music, vocals, opponentVocals, playbackRate, now, false);
			}
			else
			{
				checkVocals(music, vocals, opponentVocals, playbackRate, now, false);
			}
		}

		return songPosition;
	}

	public function checkVocals(music:FlxSound, vocals:FlxSound, opponentVocals:FlxSound, playbackRate:Float, now:Float, force:Bool = false):Bool
	{
		if (!force && now - lastResyncStamp < resyncCooldown)
			return false;

		var maxDrift:Float = vocalsDriftMs * playbackRate;
		var musicTime:Float = music.time;
		var needVocals:Bool = false;
		var needOpp:Bool = false;

		if (vocals != null && vocals.length > 0 && musicTime < vocals.length - 50)
			needVocals = force || !vocals.playing || Math.abs(vocals.time - musicTime) > maxDrift;

		if (opponentVocals != null && opponentVocals.length > 0 && musicTime < opponentVocals.length - 50)
			needOpp = force || !opponentVocals.playing || Math.abs(opponentVocals.time - musicTime) > maxDrift;

		if (!needVocals && !needOpp)
			return false;

		if (needVocals) syncTrack(vocals, musicTime, playbackRate);
		if (needOpp) syncTrack(opponentVocals, musicTime, playbackRate);
		lastResyncStamp = now;
		return true;
	}

	public function forceResync(music:FlxSound, vocals:FlxSound, opponentVocals:FlxSound, playbackRate:Float, offset:Float = 0):Float
	{
		if (music == null) return 0;

		if (!music.playing)
			music.play();
		#if FLX_PITCH
		music.pitch = playbackRate;
		#end

		var musicTime:Float = music.time;
		syncTrack(vocals, musicTime, playbackRate);
		syncTrack(opponentVocals, musicTime, playbackRate);

		lastStamp = Timer.stamp();
		lastMusicTime = musicTime;
		lastResyncStamp = lastStamp;
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

		track.pause();
		track.time = targetTime;
		#if FLX_PITCH
		track.pitch = playbackRate;
		#end
		track.play(false, targetTime);
	}
}