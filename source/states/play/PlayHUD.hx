package states.play;

import flixel.util.FlxStringUtil;
import objects.Bar;
import objects.Character;
import objects.HealthIcon;
import states.PlayState;

class PlayHUD extends FlxSpriteGroup
{
	public var healthBar:Bar;
	public var timeBar:Bar;
	public var timeTxt:FlxText;
	public var scoreTxt:FlxText;
	public var botplayTxt:FlxText;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	public var songPercent:Float = 0;
	public var botplaySine:Float = 0;
	public var scoreTxtTween:FlxTween;
	var _lastTimeSeconds:Int = -1;

	public function new(bf:Character, dad:Character, songTitle:String, getHealth:Void->Float, isBotplay:Bool)
	{
		super();

		var showTime:Bool = (ClientPrefs.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(PlayState.STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = showTime;
		if (ClientPrefs.data.downScroll) timeTxt.y = FlxG.height - 44;
		if (ClientPrefs.data.timeBarType == 'Song Name') timeTxt.text = songTitle;

		timeBar = new Bar(0, timeTxt.y + (timeTxt.height / 4), 'timeBar', function() return songPercent, 0, 1);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		add(timeBar);
		add(timeTxt);

		if (ClientPrefs.data.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', getHealth, 0, 2);
		healthBar.screenCenter(X);
		healthBar.leftToRight = false;
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors(dad, bf);
		add(healthBar);

		iconP1 = new HealthIcon(bf.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.data.hideHud;
		iconP2.alpha = ClientPrefs.data.healthBarAlpha;
		add(iconP2);

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		add(scoreTxt);

		botplayTxt = new FlxText(400, healthBar.y - 90, FlxG.width - 800, Language.getPhrase("Botplay").toUpperCase(), 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = isBotplay;
		add(botplayTxt);
		if (ClientPrefs.data.downScroll)
			botplayTxt.y = healthBar.y + 70;
	}

	public function reloadHealthBarColors(dad:Character, bf:Character):Void
	{
		healthBar.setColors(
			FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(bf.healthColorArray[0], bf.healthColorArray[1], bf.healthColorArray[2])
		);
	}

	public function fadeInTime():Void
	{
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
	}

	public function updateTime(songPos:Float, songLength:Float):Void
	{
		var curTime:Float = Math.max(0, songPos - ClientPrefs.data.noteOffset);
		songPercent = (songLength > 0) ? (curTime / songLength) : 0;

		if (!timeTxt.visible || ClientPrefs.data.timeBarType == 'Song Name') return;

		var songCalc:Float = (ClientPrefs.data.timeBarType == 'Time Elapsed') ? curTime : (songLength - curTime);
		var secondsTotal:Int = Math.floor(songCalc / 1000);
		if (secondsTotal < 0) secondsTotal = 0;

		if (secondsTotal != _lastTimeSeconds)
		{
			_lastTimeSeconds = secondsTotal;
			timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
		}
	}

	public function updateBotplay(elapsed:Float):Void
	{
		if (botplayTxt == null || !botplayTxt.visible) return;
		botplaySine += 180 * elapsed;
		botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
	}

	public function bopScore():Void
	{
		if (!ClientPrefs.data.scoreZoom) return;
		if (scoreTxtTween != null) scoreTxtTween.cancel();

		scoreTxt.scale.set(1.075, 1.075);
		scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
			onComplete: function(_) scoreTxtTween = null
		});
	}

	public function bopIcons():Void
	{
		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);
		iconP1.updateHitbox();
		iconP2.updateHitbox();
	}

	public function updateIconsScale(elapsed:Float, playbackRate:Float):Void
	{
		var mult:Float = CoolUtil.expLerp(iconP1.scale.x, 1, 9 * playbackRate, elapsed);
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		mult = CoolUtil.expLerp(iconP2.scale.x, 1, 9 * playbackRate, elapsed);
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();
	}

	public function updateIconsPosition():Void
	{
		var iconOffset:Int = 26;
		iconP1.x = healthBar.barCenter + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.barCenter - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
	}

	public function updateHealth():Void
	{
		if (healthBar == null || !healthBar.enabled || healthBar.valueFunction == null) return;
		var newPercent:Null<Float> = FlxMath.remapToRange(
			FlxMath.bound(healthBar.valueFunction(), healthBar.bounds.min, healthBar.bounds.max),
			healthBar.bounds.min, healthBar.bounds.max, 0, 100
		);
		var target:Float = (newPercent != null ? newPercent : 0);
		if (healthBar.percent == target) return;

		healthBar.percent = target;

		if (iconP1 != null && iconP1.animation.curAnim != null)
			iconP1.animation.curAnim.curFrame = (healthBar.percent < 20) ? 1 : 0;
		if (iconP2 != null && iconP2.animation.curAnim != null)
			iconP2.animation.curAnim.curFrame = (healthBar.percent > 80) ? 1 : 0;
	}
}