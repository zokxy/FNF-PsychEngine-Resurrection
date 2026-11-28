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