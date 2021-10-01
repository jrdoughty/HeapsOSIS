import osis.EntityManager;
import Common;
import h2d.Object;
import h2d.Text;
import h2d.Bitmap;
import h2d.Tile;
import hxd.Res;

class CDrawable implements Component
{
    public var imageName:String;

    public function new() {}
}


class DrawableSystem extends System
{
    var sprites:Map<Int, Object> = new Map();
    var entitySet:EntitySet;

    public override function init()
        entitySet = em.getEntitySet([CDrawable, CPosition]);

    public override function loop()
    {
        entitySet.applyChanges();

        for(entity in entitySet.adds)
        {
            trace("onEntityAdded");
            var drawable = entity.get(CDrawable);
            var sprite = getSprite(drawable.imageName);
            Client.the.s2d.addChild(sprite);
            sprites.set(entity.id, sprite);
        }

        for(entity in entitySet.changes)
        {
            var pos = entity.get(CPosition);
            var sprite = sprites.get(entity.id);

            sprite.x = pos.x;
            sprite.y = pos.y;
        }

        for(entity in entitySet.removes)
        {
            var drawable = entity.get(CDrawable);

            var sprite = sprites.get(entity.id);
            Client.the.s2d.removeChild(sprite);
            sprites.remove(entity.id);
        }
    }

    public inline static function getBitmap(imageName:String)
    {
        var tile = cast(Reflect.field(Res,imageName)).toTile();
        var bitmap = new Bitmap(tile);
        return bitmap;
    }

    public inline static function getSprite(imageName:String, ?centered:Bool)
    {
        var bitmap = DrawableSystem.getBitmap(imageName);
        if(centered)
        {
            bitmap.x -= bitmap.width / 2;
            bitmap.y -= bitmap.height / 2;
        }
        var sprite = new Object();
        sprite.addChild(bitmap);
        return sprite;
    }
}


class DebugSystem extends System
{
    var labels:Map<Int, Text> = new Map();
    var entitySet:EntitySet;

    public override function init()
        entitySet = em.getEntitySet([CTest, CPosition]);

    public override function loop()
    {
        entitySet.applyChanges();

        for(entity in entitySet.adds)
        {
            trace("ondebug added");
            var pos = entity.get(CPosition);
            var label = new Text(hxd.res.DefaultFont.get());
            label.textColor = 0xFF0000;
            label.x = pos.x;
            label.y = pos.y + 80;
            label.text = "boom boom";
            Client.the.s2d.addChild(label);
            labels.set(entity.id, label);
        }

        for(entity in entitySet.changes)
        {
            var pos = entity.get(CPosition);
            var label = labels.get(entity.id);

            label.x = pos.x;
            label.y = pos.y + 80;
        }

        for(entity in entitySet.removes)
        {
            var label = labels.get(entity.id);
            Client.the.s2d.removeChild(label);
            labels.remove(entity.id);
        }
    }
}


class Client extends hxd.App
{
    var em:EntityManager = new EntityManager();
    var net:NetEntityManager;
    public static var the:Client;
    public function new()
    {
        super();
        the = this;
        trace("plop");
        hxd.Res.initEmbed();
        var ec = new EntityCreator(em);
        net = em.connect("127.0.0.1", 32000);
        net.addEvent(MessageHello, onMessage);
        net.addEvent(PingPong, onPong);
        em.addSystem(new DrawableSystem());
        em.addSystem(new DummySystem());
        em.addSystem(new DebugSystem());

    }

    function onMessage(msg:MessageHello, connection:Connection)
    {
        trace("Message: " + msg.txt);
        trace("Entity id: " + msg.entityId);

        var entity = net.entities.get(msg.entityId);
        trace("ctest " + entity.has(CTest));

        var msg = new MessageHello();
        msg.txt = "coucou";
        net.sendEvent(msg);
    }

    function onPong(msg:PingPong, connection:Connection)
    {
        trace("pong");
        var latency = haxe.Timer.stamp() - frames[msg.frameId];
        latency *= 1000;
        trace(latency);
    }

    var lastSend:Float = 0;
    var frameId:Int = 0;
    var frames:Array<Float> = new Array();

	override function update(dt:Float)
    {
        super.update(dt);
        frameId++;

        em.fixedUpdate(function()
        {
            if(haxe.Timer.stamp() - lastSend > 1)
            {
                var ping = new PingPong();
                ping.frameId = frameId;
                net.sendEvent(ping);

                lastSend = haxe.Timer.stamp();
                frames[frameId] = lastSend;

                trace("send");
            }

            em.processAllSystems();
        });
    }

    public static function main() {new Client();}
}
