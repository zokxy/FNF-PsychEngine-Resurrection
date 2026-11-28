package backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.system.System;
import openfl.utils.Assets as OpenFLAssets;
#if cpp
import cpp.vm.Gc;
#end

class MemoryManager
{
	public static var minGPUTextureSize:Int = 256;
	public static var gameplayMemoryCapMB:Float = 256.0;
	public static var gcPausedInGameplay:Bool = false;

	static var _gameplayBaselineBytes:Float = 0;
	static var _cpuProtectedPrefixes:Array<String> = ['icons/', 'fonts/', 'editors/'];
	static var _cpuProtectedKeys:Map<String, Bool> = new Map();

	public static function protectCPU(key:String):Void
	{
		if (key != null && key.length > 0)
			_cpuProtectedKeys.set(key, true);
	}

	public static function isCPUProtected(key:String):Bool
	{
		if (key == null) return true;
		if (_cpuProtectedKeys.exists(key)) return true;
		for (prefix in _cpuProtectedPrefixes)
			if (key.indexOf(prefix) != -1) return true;
		return false;
	}

	public static function canUploadGPUOnly(key:String, bitmap:BitmapData):Bool
	{
		if (bitmap == null || !ClientPrefs.data.cacheOnGPU) return false;
		if (FlxG.stage == null || FlxG.stage.context3D == null) return false;
		if (isCPUProtected(key)) return false;
		return (bitmap.width >= minGPUTextureSize || bitmap.height >= minGPUTextureSize);
	}

	public static function tryPushToGPU(key:String, bitmap:BitmapData):Bool
	{
		if (!canUploadGPUOnly(key, bitmap)) return false;
		try
		{
			bitmap.lock();
			@:privateAccess
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			if (bitmap.image != null)
				bitmap.disposeImage();
			@:privateAccess
			bitmap.readable = false;
			bitmap.unlock();
			return true;
		}
		catch (e:Dynamic)
		{
			try { bitmap.unlock(); } catch (_:Dynamic) {}
			return false;
		}
	}

	public static function disposeGraphic(graphic:FlxGraphic, ?cacheKey:String):Void
	{
		if (graphic == null) return;

		var key:String = cacheKey != null ? cacheKey : graphic.key;
		graphic.persist = false;
		graphic.destroyOnNoUse = true;

		if (graphic.bitmap != null)
		{
			@:privateAccess
			{
				if (graphic.bitmap.__texture != null)
				{
					try { graphic.bitmap.__texture.dispose(); } catch (_:Dynamic) {}
					graphic.bitmap.__texture = null;
				}
			}
			try { graphic.bitmap.disposeImage(); } catch (_:Dynamic) {}
			try { graphic.bitmap.dispose(); } catch (_:Dynamic) {}
		}

		if (key != null)
			OpenFLAssets.cache.removeBitmapData(key);
		FlxG.bitmap.remove(graphic);
		graphic.destroy();
	}

	public static function disposeSound(sound:Sound, ?cacheKey:String):Void
	{
		if (sound == null) return;
		@:privateAccess
		{
			if (sound.__buffer != null)
			{
				try { sound.__buffer.dispose(); } catch (_:Dynamic) {}
				sound.__buffer = null;
			}
		}
		try { sound.close(); } catch (_:Dynamic) {}
		if (cacheKey != null)
			OpenFLAssets.cache.removeSound(cacheKey);
	}

	public static function estimateTextureBytes():Float
	{
		var total:Float = 0;
		@:privateAccess
		for (g in FlxG.bitmap._cache)
		{
			if (g == null || g.bitmap == null) continue;
			total += g.bitmap.width * g.bitmap.height * 4.0;
		}
		return total;
	}

	public static function estimateFilterBufferBytes():Float
	{
		var total:Float = 0;
		function count(s:openfl.display.DisplayObject):Void
		{
			if (s == null) return;
			@:privateAccess
			{
				if (s.__cacheBitmapData != null) total += s.__cacheBitmapData.width * s.__cacheBitmapData.height * 4.0;
				if (s.__cacheBitmapData2 != null) total += s.__cacheBitmapData2.width * s.__cacheBitmapData2.height * 4.0;
				if (s.__cacheBitmapData3 != null) total += s.__cacheBitmapData3.width * s.__cacheBitmapData3.height * 4.0;
			}
		}
		if (FlxG.cameras != null)
			for (cam in FlxG.cameras.list)
				if (cam != null) count(cam.flashSprite);
		count(FlxG.game);
		return total;
	}

	public static function report(topN:Int = 30):Void
	{
		#if sys
		try
		{
			var list:Array<{key:String, w:Int, h:Int, bytes:Float}> = [];
			@:privateAccess
			for (key => g in FlxG.bitmap._cache)
			{
				if (g == null || g.bitmap == null) continue;
				list.push({key: key, w: g.bitmap.width, h: g.bitmap.height, bytes: g.bitmap.width * g.bitmap.height * 4.0});
			}
			list.sort(function(a, b) return a.bytes < b.bytes ? 1 : (a.bytes > b.bytes ? -1 : 0));

			var mb = function(b:Float) return Std.string(Math.round(b / 1048576 * 10) / 10) + ' MB';
			var out:String = 'Window: ${FlxG.stage.stageWidth}x${FlxG.stage.stageHeight} | game: ${FlxG.width}x${FlxG.height}\n';
			out += 'Textures in cache: ${list.length} (~${mb(estimateTextureBytes())})\n';
			out += 'Filter/shader camera buffers: ~${mb(estimateFilterBufferBytes())}\n';
			out += 'Haxe heap: ${mb(getMemoryUsageBytes())}\n\n--- heaviest textures ---\n';
			for (i in 0...Std.int(Math.min(topN, list.length)))
				out += '${mb(list[i].bytes)}\t${list[i].w}x${list[i].h}\t${list[i].key}\n';
			File.saveContent('texture_report.txt', out);
		}
		catch (_:Dynamic) {}
		#end
	}

	public static function getMemoryUsageBytes():Float
	{
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_USAGE);
		#else
		return System.totalMemory;
		#end
	}

	public static function enterGameplay():Void
	{
		#if cpp
		if (gcPausedInGameplay) return;
		Gc.run(true);
		_gameplayBaselineBytes = Gc.memInfo64(Gc.MEM_INFO_USAGE);
		Gc.enable(false);
		gcPausedInGameplay = true;
		#end
	}

	public static function exitGameplay(compact:Bool = true):Void
	{
		#if cpp
		if (gcPausedInGameplay)
		{
			Gc.enable(true);
			gcPausedInGameplay = false;
		}
		collect(compact);
		#else
		collect(compact);
		#end
	}

	public static function checkGameplayBudget():Void
	{
		#if cpp
		if (!gcPausedInGameplay) return;
		var current:Float = Gc.memInfo64(Gc.MEM_INFO_USAGE);
		var capBytes:Float = gameplayMemoryCapMB * 1024.0 * 1024.0;
		if (current - _gameplayBaselineBytes > capBytes)
		{
			Gc.enable(true);
			Gc.run(false);
			Gc.enable(false);
			_gameplayBaselineBytes = Gc.memInfo64(Gc.MEM_INFO_USAGE);
		}
		#end
	}

	public static function collect(compact:Bool = false):Void
	{
		#if cpp
		var wasPaused:Bool = gcPausedInGameplay;
		if (wasPaused) Gc.enable(true);
		Gc.run(true);
		if (compact) Gc.compact();
		if (wasPaused)
		{
			_gameplayBaselineBytes = Gc.memInfo64(Gc.MEM_INFO_USAGE);
			Gc.enable(false);
		}
		#else
		System.gc();
		#end
	}
}