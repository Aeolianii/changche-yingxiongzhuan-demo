using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

public partial class Scene2 : Node2D
{
    private const float PlayerSpeed = 210f;
    private const string AssetRoot = "res://assets/characters";
    private const string DialogueBackgroundPath = "res://assets/ui/paper/PNGs/Backgrounds/BackgroundBar.png";

    private CharacterBody2D _player = default!;
    private AnimatedSprite2D _playerSprite = default!;
    private Area2D _magistrateInteractArea = default!;
    private Control _interactionPanel = default!;
    private Control _explorationHud = default!;
    private Control _dialoguePanel = default!;
    private ColorRect _portraitBox = default!;
    private Label _portraitLabel = default!;
    private TextureRect _portraitImage = default!;
    private PanelContainer _namePlate = default!;
    private PanelContainer _paperPanel = default!;
    private MarginContainer _dialogueMargin = default!;
    private Label _speakerLabel = default!;
    private Label _dialogueLabel = default!;
    private VBoxContainer _optionBox = default!;
    private Button _nextDialogueButton = default!;
    private Button _drillButton = default!;
    private Control _drillOverlay = default!;
    private readonly List<PatrolGuard> _patrolGuards = new();
    private readonly List<InteractableNpc> _interactableNpcs = new();
    private readonly List<AmbientCloud> _ambientClouds = new();

    private bool _nearMagistrate;
    private int _dialogueIndex;
    private string _lastDirection = "down";
    private InteractableNpc _currentTarget;
    private InteractableNpc _activeNpc;

    private sealed class PatrolGuard
    {
        public Node2D Actor { get; init; } = default!;
        public AnimatedSprite2D Sprite { get; init; } = default!;
        public Vector2[] Points { get; init; } = Array.Empty<Vector2>();
        public int TargetIndex { get; set; } = 1;
        public float Speed { get; init; } = 48f;
    }

    private sealed class InteractableNpc
    {
        public Node2D Actor { get; init; } = default!;
        public AnimatedSprite2D Sprite { get; init; } = default!;
        public string DisplayName { get; init; } = "";
        public string PortraitText { get; init; } = "";
        public string PortraitPath { get; init; } = "";
        public string DialogueLine { get; init; } = "";
        public bool CanStartDrill { get; init; }
        public Color NormalModulate { get; init; }
        public Vector2 NormalScale { get; init; }
    }

    private sealed class AmbientCloud
    {
        public Node2D Node { get; init; } = default!;
        public float Speed { get; init; }
        public float ResetX { get; init; }
        public float WrapX { get; init; }
    }

    private readonly (string Speaker, string Text)[] _storyDialogues =
    {
        ("广州县令", "下官参见伏波大将军！岭南官民苦海乱久矣，听闻将军奉旨南下建水师、镇海疆，万民皆盼将军到来，扫平海患、重安山海！"),
        ("水师主帅", "本官奉旨筹建水师、筑堡固防、剿寇复岛。如今初至岭南，急需战船武备、工坊器械、粮草辎重全面支撑，还需地方鼎力配合。"),
        ("广州县令", "下官早已提前统筹全域资源，全境备战就位，可保水师长期驻海、跨海征战粮草无忧。")
    };

    public override void _Ready()
    {
        BuildScene();
        BuildUi();
    }

    public override void _PhysicsProcess(double delta)
    {
        UpdateAmbientBackground((float)delta);
        RefreshExplorationHud();

        if (_dialoguePanel.Visible || _drillOverlay.Visible)
        {
            _player.Velocity = Vector2.Zero;
            _playerSprite.Play($"idle_{_lastDirection}");
            UpdatePatrolGuards((float)delta);
            return;
        }

        Vector2 input = Input.GetVector("move_left", "move_right", "move_up", "move_down");
        _player.Velocity = input * PlayerSpeed;
        _player.MoveAndSlide();
        UpdatePlayerAnimation(input);
        UpdatePatrolGuards((float)delta);
        UpdateInteractionTarget();
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed("interact") && _currentTarget != null && !_dialoguePanel.Visible && !_drillOverlay.Visible)
            OpenNpcDialogue(_currentTarget);
    }

    private void BuildScene()
    {
        InitializeWorldNodes();
        AddSceneSoldiers();
        AddMagistrate();
        AddCommander();
        AddPlayer();
    }

    private void InitializeWorldNodes()
    {
        Material waterMaterial = CreateWaterMaterial();
        Texture2D waterTexture = CreateSeaWaterTexture();
        ApplyWaterSurface(GetNode<Node>("World/Water"), waterMaterial, waterTexture);

        _ambientClouds.Clear();
        RegisterAmbientCloud("World/DistantBackdrop/Clouds/CloudLeftHigh", 7f, -210f, 470f);
        RegisterAmbientCloud("World/DistantBackdrop/Clouds/CloudLeftLow", 4.5f, -180f, 430f);
        RegisterAmbientCloud("World/DistantBackdrop/Clouds/CloudRightHigh", 6.2f, 930f, 1500f);
        RegisterAmbientCloud("World/DistantBackdrop/Clouds/CloudRightLow", 3.8f, 900f, 1500f);
    }

    private void RegisterAmbientCloud(string path, float speed, float resetX, float wrapX)
    {
        _ambientClouds.Add(new AmbientCloud
        {
            Node = GetNode<Node2D>(path),
            Speed = speed,
            ResetX = resetX,
            WrapX = wrapX
        });
    }

    private void UpdateAmbientBackground(float delta)
    {
        foreach (AmbientCloud cloud in _ambientClouds)
        {
            cloud.Node.Position += new Vector2(cloud.Speed * delta, 0f);
            if (cloud.Node.Position.X > cloud.WrapX)
                cloud.Node.Position = new Vector2(cloud.ResetX, cloud.Node.Position.Y);
        }
    }

    private Material CreateWaterMaterial()
    {
        var shader = GD.Load<Shader>("res://shaders/water_2d_distortion.gdshader");
        var material = new ShaderMaterial { Shader = shader };

        material.SetShaderParameter("waterNoise", CreateNoiseTexture(0.045f, 4, 0.55f));
        material.SetShaderParameter("waterDistortionNoise", CreateNoiseTexture(0.025f, 3, 0.5f));
        material.SetShaderParameter("waterColor", new Color(0.12f, 0.55f, 0.76f, 1f));
        material.SetShaderParameter("colorCorection", 0.28f);
        material.SetShaderParameter("distortionForce", 0.01f);
        material.SetShaderParameter("WDBrightness", 1.25f);
        material.SetShaderParameter("WDFreq", 0.62f);
        material.SetShaderParameter("WDSize", 0.92f);
        material.SetShaderParameter("WDSpeed", 4f);
        material.SetShaderParameter("tiling", new Vector2(4.0f, 2.4f));
        material.SetShaderParameter("offSetSpeed", new Vector2(0.08f, 0.035f));
        material.SetShaderParameter("backGroundDirX", 0.01f);
        material.SetShaderParameter("backGroundDirY", 0.006f);
        return material;
    }

    private static Texture2D CreateSeaWaterTexture()
    {
        var noise = new FastNoiseLite
        {
            NoiseType = FastNoiseLite.NoiseTypeEnum.SimplexSmooth,
            Frequency = 0.035f,
            FractalOctaves = 5,
            FractalGain = 0.48f
        };

        return new NoiseTexture2D
        {
            Width = 512,
            Height = 512,
            Noise = noise,
            Seamless = true
        };
    }

    private static NoiseTexture2D CreateNoiseTexture(float frequency, int octaves, float gain)
    {
        var noise = new FastNoiseLite
        {
            NoiseType = FastNoiseLite.NoiseTypeEnum.SimplexSmooth,
            Frequency = frequency,
            FractalOctaves = octaves,
            FractalGain = gain
        };

        return new NoiseTexture2D
        {
            Width = 512,
            Height = 512,
            Noise = noise,
            Seamless = true
        };
    }

    private static void ApplyWaterSurface(Node node, Material material, Texture2D texture)
    {
        if (node is Polygon2D polygon)
        {
            polygon.Texture = texture;
            polygon.TextureScale = new Vector2(0.55f, 0.55f);
            polygon.TextureOffset = new Vector2(-80f, -40f);
            polygon.Color = Colors.White;
            polygon.Material = material;
        }

        foreach (Node child in node.GetChildren())
            ApplyWaterSurface(child, material, texture);
    }

    private void AddSceneSoldiers()
    {
        AddPatrolGuard("LeftPatrolSoldier", "right", new[]
        {
            new Vector2(190, 310),
            new Vector2(274, 310),
            new Vector2(274, 430),
            new Vector2(190, 430)
        });

        AddPatrolGuard("RightPatrolSoldier", "left", new[]
        {
            new Vector2(1154, 310),
            new Vector2(1070, 310),
            new Vector2(1070, 430),
            new Vector2(1154, 430)
        });

        var leftGuard = AddStandingActor("MagistrateLeftGuard", $"{AssetRoot}/soldier", new Vector2(560, 600), "right", 1.15f, new Color(1, 1, 1, 0.98f));
        RegisterInteractable(leftGuard, "左侧护卫", "兵", FindImageInAssetDirectory($"{AssetRoot}/soldier", "picture.png"), false, "封侯非我意，但愿海波平。");

        var rightGuard = AddStandingActor("MagistrateRightGuard", $"{AssetRoot}/soldier", new Vector2(784, 600), "left", 1.15f, new Color(1, 1, 1, 0.98f));
        RegisterInteractable(rightGuard, "右侧护卫", "兵", FindImageInAssetDirectory($"{AssetRoot}/soldier", "picture.png"), false, "遥知夷岛微茫外，未敢忘危负岁华。");
    }

    private Node2D AddPatrolGuard(string name, string initialDirection, Vector2[] patrolPoints)
    {
        Node2D actor = AddStandingActor(name, $"{AssetRoot}/soldier", patrolPoints[0], initialDirection, 1.15f, new Color(1, 1, 1, 0.98f));
        var sprite = actor.GetNode<AnimatedSprite2D>("Sprite");
        sprite.Play($"walk_{initialDirection}");

        _patrolGuards.Add(new PatrolGuard
        {
            Actor = actor,
            Sprite = sprite,
            Points = patrolPoints,
            TargetIndex = 1,
            Speed = 48f
        });

        return actor;
    }

    private void UpdatePatrolGuards(float delta)
    {
        foreach (PatrolGuard guard in _patrolGuards)
        {
            Vector2 target = guard.Points[guard.TargetIndex];
            Vector2 toTarget = target - guard.Actor.Position;
            float step = guard.Speed * delta;

            if (toTarget.Length() <= step)
            {
                guard.Actor.Position = target;
                guard.TargetIndex = (guard.TargetIndex + 1) % guard.Points.Length;
                target = guard.Points[guard.TargetIndex];
                toTarget = target - guard.Actor.Position;
            }
            else
            {
                guard.Actor.Position += toTarget.Normalized() * step;
            }

            string direction = GetDirectionFromVector(toTarget);
            guard.Sprite.Play($"walk_{direction}");
            guard.Actor.ZIndex = (int)guard.Actor.Position.Y;
        }
    }

    private static string GetDirectionFromVector(Vector2 movement)
    {
        if (Math.Abs(movement.X) > Math.Abs(movement.Y))
            return movement.X >= 0f ? "right" : "left";

        return movement.Y >= 0f ? "down" : "up";
    }

    private void RegisterInteractable(Node2D actor, string displayName, string portraitText, string portraitPath, bool canStartDrill, string dialogueLine = "")
    {
        var sprite = actor.GetNode<AnimatedSprite2D>("Sprite");
        _interactableNpcs.Add(new InteractableNpc
        {
            Actor = actor,
            Sprite = sprite,
            DisplayName = displayName,
            PortraitText = portraitText,
            PortraitPath = portraitPath,
            DialogueLine = string.IsNullOrEmpty(dialogueLine) ? $"我是{displayName}" : dialogueLine,
            CanStartDrill = canStartDrill,
            NormalModulate = sprite.Modulate,
            NormalScale = sprite.Scale
        });
    }

    private void UpdateInteractionTarget()
    {
        const float interactRadius = 92f;
        InteractableNpc nearest = null;
        float nearestDistance = interactRadius;

        foreach (InteractableNpc npc in _interactableNpcs)
        {
            float distance = _player.GlobalPosition.DistanceTo(npc.Actor.GlobalPosition);
            if (distance < nearestDistance)
            {
                nearest = npc;
                nearestDistance = distance;
            }
        }

        if (_currentTarget == nearest)
            return;

        ClearTargetHighlight(_currentTarget);
        _currentTarget = nearest;
        ApplyTargetHighlight(_currentTarget);
    }

    private static void ApplyTargetHighlight(InteractableNpc npc)
    {
        if (npc == null)
            return;

        npc.Sprite.Modulate = new Color(1.35f, 1.22f, 0.72f, npc.NormalModulate.A);
        npc.Sprite.Scale = npc.NormalScale * 1.08f;
    }

    private static void ClearTargetHighlight(InteractableNpc npc)
    {
        if (npc == null)
            return;

        npc.Sprite.Modulate = npc.NormalModulate;
        npc.Sprite.Scale = npc.NormalScale;
    }

    private void AddSoldiers()
    {
        Vector2[] positions =
        {
            new(246, 380), // 左舷外侧
            new(1098, 380), // 右舷外侧
            new(560, 600), // 县令左护卫
            new(784, 600) // 县令右护卫
        };

        for (int i = 0; i < positions.Length; i++)
        {
            string facing = positions[i].X < 672 ? "right" : "left";
            AddStandingActor($"Soldier{i + 1}", $"{AssetRoot}/soldier", positions[i], facing, 1.15f, new Color(1, 1, 1, 0.98f));
        }
    }

    private void AddMagistrate()
    {
        string magistrateDir = FindAssetDirectory("magistrate");
        var magistrate = AddStandingActor("GuangzhouCountyMagistrate", magistrateDir, new Vector2(672, 585), "down", 1.25f, Colors.White);
        RegisterInteractable(magistrate, "广州县令", "县", FindImageInAssetDirectory(magistrateDir, "picture.png"), true, "先天下之忧而忧，后天下之乐而乐。");
    }

    private void AddCommander()
    {
        var commander = AddStandingActor("FleetCommander", $"{AssetRoot}/soldier", new Vector2(672, 425), "down", 1.35f, new Color(0.9f, 1f, 1f));
        RegisterInteractable(commander, "中军士兵", "兵", FindImageInAssetDirectory($"{AssetRoot}/soldier", "picture.png"), false, "将军找我何事？");
    }

    private Node2D AddStandingActor(string name, string assetDir, Vector2 position, string direction, float scale, Color modulate)
    {
        Node2D actor = GetExistingActor(name) ?? CreateRuntimeStandingActor(name, position);
        actor.ZIndex = (int)actor.Position.Y;

        var sprite = actor.GetNodeOrNull<AnimatedSprite2D>("Sprite");
        if (sprite == null)
        {
            sprite = new AnimatedSprite2D
            {
                Name = "Sprite",
                Scale = new Vector2(scale, scale),
                Modulate = modulate
            };
            actor.AddChild(sprite);
        }

        sprite.SpriteFrames = BuildSpriteFrames(assetDir);
        sprite.Play($"idle_{direction}");

        EnsureStandingActorCollision(actor);

        return actor;
    }

    private Node2D GetExistingActor(string name)
    {
        return GetNodeOrNull<Node2D>($"World/Actors/PatrolGuards/{name}")
            ?? GetNodeOrNull<Node2D>($"World/Actors/Npcs/{name}");
    }

    private Node2D CreateRuntimeStandingActor(string name, Vector2 position)
    {
        var actor = new Node2D { Name = name, Position = position };
        GetNodeOrNull<Node2D>("World/Actors/Npcs")?.AddChild(actor);
        if (actor.GetParent() == null)
            AddChild(actor);

        return actor;
    }

    private static void EnsureStandingActorCollision(Node2D actor)
    {
        var body = actor.GetNodeOrNull<StaticBody2D>("Body");
        if (body == null)
        {
            body = new StaticBody2D { Name = "Body", CollisionLayer = 1 };
            actor.AddChild(body);
        }

        if (body.GetNodeOrNull<CollisionShape2D>("Collision") == null)
        {
            body.AddChild(new CollisionShape2D
            {
                Name = "Collision",
                Shape = new CircleShape2D { Radius = 12 }
            });
        }
    }

    private void AddPlayer()
    {
        _player = GetNodeOrNull<CharacterBody2D>("World/Actors/Player");
        if (_player == null)
        {
            _player = new CharacterBody2D
            {
                Name = "Player",
                Position = new Vector2(672, 760),
                CollisionLayer = 2,
                CollisionMask = 1,
                ZIndex = 760
            };
            GetNodeOrNull<Node2D>("World/Actors")?.AddChild(_player);
            if (_player.GetParent() == null)
                AddChild(_player);
        }

        _player.ZIndex = (int)_player.Position.Y;

        _playerSprite = _player.GetNodeOrNull<AnimatedSprite2D>("Sprite");
        if (_playerSprite == null)
        {
            _playerSprite = new AnimatedSprite2D
            {
                Name = "Sprite",
                Scale = new Vector2(1.25f, 1.25f)
            };
            _player.AddChild(_playerSprite);
        }

        _playerSprite.SpriteFrames = BuildSpriteFrames($"{AssetRoot}/protagonist");
        _playerSprite.Play("idle_down");

        if (_player.GetNodeOrNull<CollisionShape2D>("Collision") == null)
        {
            _player.AddChild(new CollisionShape2D
            {
                Name = "Collision",
                Shape = new CircleShape2D { Radius = 18 },
                Position = new Vector2(0, 12)
            });
        }

        InitializePlayerCamera();
    }

    private void InitializePlayerCamera()
    {
        var camera = _player.GetNodeOrNull<Camera2D>("Camera2D");
        if (camera == null)
        {
            camera = new Camera2D
            {
                Name = "Camera2D",
                Zoom = new Vector2(1.3f, 1.3f),
                PositionSmoothingEnabled = true,
                PositionSmoothingSpeed = 6f
            };
            _player.AddChild(camera);
        }

        camera.Enabled = true;
        camera.MakeCurrent();
        camera.LimitLeft = 0;
        camera.LimitTop = 0;
        camera.LimitRight = 1344;
        camera.LimitBottom = 896;
    }

    private SpriteFrames BuildSpriteFrames(string assetDir)
    {
        var frames = new SpriteFrames();
        foreach (string defaultAnim in frames.GetAnimationNames())
            frames.RemoveAnimation(defaultAnim);

        foreach (string direction in new[] { "down", "left", "right", "up" })
        {
            AddAnimationFrames(frames, $"idle_{direction}", $"{assetDir}/standard/idle/{direction}", 2, 2.5);
            AddAnimationFrames(frames, $"walk_{direction}", $"{assetDir}/standard/walk/{direction}", 9, 10.0);
        }

        return frames;
    }

    private static void AddAnimationFrames(SpriteFrames spriteFrames, string animation, string folder, int maxFrames, double fps)
    {
        spriteFrames.AddAnimation(animation);
        spriteFrames.SetAnimationLoopMode(animation, SpriteFrames.LoopMode.Linear);
        spriteFrames.SetAnimationSpeed(animation, fps);

        for (int i = 1; i <= maxFrames; i++)
        {
            string path = $"{folder}/{i}.png";
            if (FileAccess.FileExists(path))
                spriteFrames.AddFrame(animation, LoadTextureFromFile(path));
        }
    }

    private static Texture2D LoadTextureFromFile(string resPath)
    {
        var image = new Image();
        string globalPath = ProjectSettings.GlobalizePath(resPath);
        Error error = image.Load(globalPath);
        if (error != Error.Ok)
        {
            GD.PushError($"Failed to load image '{resPath}': {error}");
            return new PlaceholderTexture2D { Size = new Vector2I(32, 32) };
        }

        return ImageTexture.CreateFromImage(image);
    }

    private string FindAssetDirectory(string normalizedNeedle)
    {
        using DirAccess dir = DirAccess.Open(AssetRoot);
        foreach (string child in dir.GetDirectories())
        {
            string normalized = NormalizeDirectoryName(child);
            if (normalized.Contains(normalizedNeedle, StringComparison.OrdinalIgnoreCase))
                return $"{AssetRoot}/{child}";
        }

        GD.PushWarning($"Could not find asset directory containing '{normalizedNeedle}', falling back to protagonist.");
        return $"{AssetRoot}/protagonist";
    }

    private static string FindImageInAssetDirectory(string assetDir, string normalizedFileName)
    {
        using DirAccess dir = DirAccess.Open(assetDir);
        if (dir == null)
            return $"{assetDir}/{normalizedFileName}";

        string normalizedTarget = NormalizeDirectoryName(normalizedFileName);
        foreach (string fileName in dir.GetFiles())
        {
            if (NormalizeDirectoryName(fileName) == normalizedTarget)
                return $"{assetDir}/{fileName}";
        }

        return $"{assetDir}/{normalizedFileName}";
    }

    private static string NormalizeDirectoryName(string value)
    {
        return value
            .Replace("\u200c", string.Empty)
            .Replace("\u200d", string.Empty)
            .Replace("\ufeff", string.Empty)
            .Trim();
    }

    private void UpdatePlayerAnimation(Vector2 input)
    {
        _player.ZIndex = (int)_player.GlobalPosition.Y;

        if (input == Vector2.Zero)
        {
            _playerSprite.Play($"idle_{_lastDirection}");
            return;
        }

        _lastDirection = Math.Abs(input.X) > Math.Abs(input.Y)
            ? input.X > 0 ? "right" : "left"
            : input.Y > 0 ? "down" : "up";

        _playerSprite.Play($"walk_{_lastDirection}");
    }

    private void BuildUi()
    {
        var canvas = GetNode<CanvasLayer>("UI");

        _explorationHud = GetNode<Control>("UI/ExplorationHUD");
        _explorationHud.Call("set_main_task", "巡视水师驻地");

        _interactionPanel = CreateInteractionPanel();
        canvas.AddChild(_interactionPanel);

        InitializeDialoguePanel();

        _drillOverlay = CreateDrillOverlay();
        canvas.AddChild(_drillOverlay);
        RefreshExplorationHud();
    }

    private void InitializeDialoguePanel()
    {
        _dialoguePanel = GetNode<Control>("UI/DialoguePanel");
        _paperPanel = GetNode<PanelContainer>("UI/DialoguePanel/FullWidthPaperDialogueBox");
        _dialogueMargin = GetNode<MarginContainer>("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin");
        _dialogueLabel = GetNode<Label>("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel");
        _optionBox = GetNode<VBoxContainer>("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox");
        _nextDialogueButton = GetNode<Button>("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/NextDialogueButton");
        _portraitImage = GetNode<TextureRect>("UI/DialoguePanel/LargeTransparentPortrait");
        _portraitBox = GetNode<ColorRect>("UI/DialoguePanel/PortraitBox");
        _portraitLabel = GetNode<Label>("UI/DialoguePanel/PortraitLabel");
        _namePlate = GetNode<PanelContainer>("UI/DialoguePanel/NamePlate");
        _speakerLabel = GetNode<Label>("UI/DialoguePanel/NamePlate/SpeakerLabel");

        ApplyDialoguePanelStyles();
        _nextDialogueButton.Pressed += AdvanceDialogue;
        ApplyDialogueSide(false);
        _dialoguePanel.Hide();
    }

    private void ApplyDialoguePanelStyles()
    {
        var paperStyle = new StyleBoxTexture
        {
            Texture = GD.Load<Texture2D>(DialogueBackgroundPath),
            ContentMarginLeft = 5,
            ContentMarginRight = 5,
            ContentMarginTop = 5,
            ContentMarginBottom = 5,
            AxisStretchHorizontal = StyleBoxTexture.AxisStretchMode.Stretch,
            AxisStretchVertical = StyleBoxTexture.AxisStretchMode.Stretch
        };
        _paperPanel.AddThemeStyleboxOverride("panel", paperStyle);

        var nameStyle = new StyleBoxFlat
        {
            BgColor = new Color(0.03f, 0.025f, 0.02f, 0.78f),
            BorderColor = new Color(0.72f, 0.58f, 0.34f, 0.65f),
            BorderWidthBottom = 2
        };
        _namePlate.AddThemeStyleboxOverride("panel", nameStyle);

        _nextDialogueButton.AddThemeStyleboxOverride("normal", CreateOptionStyle(new Color(0.72f, 0.58f, 0.34f, 0.18f)));
        _nextDialogueButton.AddThemeStyleboxOverride("hover", CreateOptionStyle(new Color(0.72f, 0.58f, 0.34f, 0.32f)));
        _nextDialogueButton.AddThemeStyleboxOverride("pressed", CreateOptionStyle(new Color(0.52f, 0.35f, 0.18f, 0.34f)));
    }

    private Control CreateInteractionPanel()
    {
        var panel = new PanelContainer
        {
            Name = "InteractionPanel",
            Position = new Vector2(548, 650),
            Size = new Vector2(250, 92),
            Visible = false
        };

        var box = new VBoxContainer { CustomMinimumSize = new Vector2(250, 92) };
        panel.AddChild(box);

        var meetButton = new Button { Text = "拜见", CustomMinimumSize = new Vector2(220, 40) };
        meetButton.Pressed += StartDialogue;
        box.AddChild(meetButton);

        _drillButton = new Button { Text = "操练", CustomMinimumSize = new Vector2(220, 40), Visible = false };
        _drillButton.Pressed += ShowDrill;
        box.AddChild(_drillButton);

        return panel;
    }

    private Control CreateDrillOverlay()
    {
        var root = new Control
        {
            Name = "DrillOverlay",
            Visible = false,
            Size = new Vector2(1344, 896)
        };

        var dim = new ColorRect
        {
            Color = new Color(0.02f, 0.05f, 0.08f, 0.72f),
            Size = new Vector2(1344, 896)
        };
        root.AddChild(dim);

        var title = new Label
        {
            Text = "水师操练",
            HorizontalAlignment = HorizontalAlignment.Center,
            Position = new Vector2(0, 96),
            Size = new Vector2(1344, 70)
        };
        title.AddThemeFontSizeOverride("font_size", 48);
        root.AddChild(title);

        var body = new Label
        {
            Text = "战鼓既发，左右舷师列阵。弓弩、火炮、登舷诸队依令操演，旗帜在甲板上传令往复，南疆水师初具军容。",
            AutowrapMode = TextServer.AutowrapMode.WordSmart,
            HorizontalAlignment = HorizontalAlignment.Center,
            Position = new Vector2(220, 180),
            Size = new Vector2(904, 120)
        };
        body.AddThemeFontSizeOverride("font_size", 28);
        root.AddChild(body);

        var note = new Label
        {
            Text = "备注：有待完善，可以用 CG 来代替演示。",
            HorizontalAlignment = HorizontalAlignment.Center,
            Position = new Vector2(220, 258),
            Size = new Vector2(904, 42)
        };
        note.AddThemeFontSizeOverride("font_size", 22);
        note.AddThemeColorOverride("font_color", new Color(0.88f, 0.84f, 0.72f));
        root.AddChild(note);

        AddDrillShip(root, new Vector2(410, 500), -9);
        AddDrillShip(root, new Vector2(672, 430), 0);
        AddDrillShip(root, new Vector2(934, 500), 9);

        var close = new Button
        {
            Text = "返回甲板",
            Position = new Vector2(572, 760),
            Size = new Vector2(200, 52)
        };
        close.Pressed += CloseDrillOverlay;
        root.AddChild(close);

        return root;
    }

    private void AddDrillShip(Control root, Vector2 position, float rotationDegrees)
    {
        var ship = new Polygon2D
        {
            Position = position,
            RotationDegrees = rotationDegrees,
            Polygon = new[]
            {
                new Vector2(0, -88), new Vector2(48, -48), new Vector2(38, 88),
                new Vector2(0, 118), new Vector2(-38, 88), new Vector2(-48, -48)
            },
            Color = new Color(0.55f, 0.33f, 0.18f)
        };
        root.AddChild(ship);

        var sail = new Polygon2D
        {
            Position = position + new Vector2(0, -12),
            RotationDegrees = rotationDegrees,
            Polygon = new[] { new Vector2(-8, -66), new Vector2(45, 20), new Vector2(-8, 72) },
            Color = new Color(0.86f, 0.78f, 0.55f)
        };
        root.AddChild(sail);
    }

    private void ShowInteractionPanel()
    {
        if (_drillOverlay.Visible)
            return;

        _interactionPanel.Show();
    }

    private void OpenNpcDialogue(InteractableNpc npc)
    {
        _activeNpc = npc;
        _interactionPanel.Hide();
        _dialoguePanel.Show();
        RefreshExplorationHud();
        _optionBox.Show();
        _nextDialogueButton.Hide();

        _speakerLabel.Text = npc.DisplayName;
        _dialogueLabel.Text = npc.DialogueLine;
        _portraitLabel.Text = npc.PortraitText;
        SetPortrait(npc.PortraitPath, npc.PortraitText, false);

        ClearOptionButtons();

        if (npc.CanStartDrill)
            AddDialogueOption("开始操练。", StartDrillFromDialogue);

        AddDialogueOption("无事。", CloseNpcDialogue);
    }

    private void AddDialogueOption(string text, Action action)
    {
        var button = new Button
        {
            Text = text,
            CustomMinimumSize = new Vector2(820, 28),
            Alignment = HorizontalAlignment.Left
        };
        button.AddThemeFontSizeOverride("font_size", 21);
        button.AddThemeColorOverride("font_color", new Color(0.08f, 0.06f, 0.04f));
        button.AddThemeColorOverride("font_hover_color", new Color(0.28f, 0.12f, 0.04f));
        button.AddThemeStyleboxOverride("normal", CreateOptionStyle(new Color(0.88f, 0.82f, 0.62f, 0.0f)));
        button.AddThemeStyleboxOverride("hover", CreateOptionStyle(new Color(0.72f, 0.58f, 0.34f, 0.2f)));
        button.AddThemeStyleboxOverride("pressed", CreateOptionStyle(new Color(0.52f, 0.35f, 0.18f, 0.28f)));
        button.Pressed += action;
        _optionBox.AddChild(button);
    }

    private static StyleBoxFlat CreateOptionStyle(Color bgColor)
    {
        return new StyleBoxFlat
        {
            BgColor = bgColor,
            ContentMarginLeft = 18,
            ContentMarginRight = 12,
            ContentMarginTop = 2,
            ContentMarginBottom = 2
        };
    }

    private void ClearOptionButtons()
    {
        foreach (Node child in _optionBox.GetChildren())
        {
            _optionBox.RemoveChild(child);
            child.QueueFree();
        }
    }

    private void SetPortrait(string portraitPath, string fallbackText, bool showOnLeft)
    {
        ApplyDialogueSide(showOnLeft);

        if (!string.IsNullOrEmpty(portraitPath) && FileAccess.FileExists(portraitPath))
        {
            _portraitImage.Texture = LoadTextureFromFile(portraitPath);
            _portraitImage.Show();
            _portraitBox.Hide();
            _portraitLabel.Hide();
            return;
        }

        _portraitImage.Texture = null;
        _portraitImage.Hide();
        _portraitBox.Show();
        _portraitBox.Position = showOnLeft ? new Vector2(48, 492) : new Vector2(1076, 492);
        _portraitLabel.Text = fallbackText;
        _portraitLabel.Position = _portraitBox.Position;
        _portraitLabel.Show();
    }

    private void ApplyDialogueSide(bool portraitOnLeft)
    {
        if (portraitOnLeft)
        {
            _portraitImage.Position = new Vector2(-20, 410);
            _namePlate.Position = new Vector2(34, 846);
            SetDialogueMargins(450, 44, 16, 18);
            _dialogueLabel.CustomMinimumSize = new Vector2(800, 62);
            _optionBox.CustomMinimumSize = new Vector2(800, 50);
        }
        else
        {
            _portraitImage.Position = new Vector2(884, 410);
            _namePlate.Position = new Vector2(1078, 846);
            SetDialogueMargins(54, 450, 16, 18);
            _dialogueLabel.CustomMinimumSize = new Vector2(800, 62);
            _optionBox.CustomMinimumSize = new Vector2(800, 50);
        }
    }

    private void SetDialogueMargins(int left, int right, int top, int bottom)
    {
        _dialogueMargin.AddThemeConstantOverride("margin_left", left);
        _dialogueMargin.AddThemeConstantOverride("margin_right", right);
        _dialogueMargin.AddThemeConstantOverride("margin_top", top);
        _dialogueMargin.AddThemeConstantOverride("margin_bottom", bottom);
    }

    private void CloseNpcDialogue()
    {
        _dialoguePanel.Hide();
        _activeNpc = null;
        ClearOptionButtons();
        RefreshExplorationHud();
    }

    private void StartDrillFromDialogue()
    {
        CloseNpcDialogue();
        StartDialogue();
    }

    private void StartDialogue()
    {
        _interactionPanel.Hide();
        _optionBox.Hide();
        _nextDialogueButton.Show();
        _dialogueIndex = 0;
        ShowDialogueLine();
        _dialoguePanel.Show();
        RefreshExplorationHud();
    }

    private void AdvanceDialogue()
    {
        _dialogueIndex++;
        if (_dialogueIndex >= _storyDialogues.Length)
        {
            _dialoguePanel.Hide();
            _optionBox.Show();
            ShowDrill();
            return;
        }

        ShowDialogueLine();
    }

    private void ShowDialogueLine()
    {
        _speakerLabel.Text = _storyDialogues[_dialogueIndex].Speaker;
        _dialogueLabel.Text = _storyDialogues[_dialogueIndex].Text;
        bool isMagistrate = _storyDialogues[_dialogueIndex].Speaker == "广州县令";
        _portraitLabel.Text = isMagistrate ? "县" : "帅";
        string portraitPath = isMagistrate
            ? FindImageInAssetDirectory(FindAssetDirectory("magistrate"), "picture.png")
            : FindImageInAssetDirectory($"{AssetRoot}/protagonist", "picture.png");
        SetPortrait(portraitPath, isMagistrate ? "县" : "帅", !isMagistrate);
        _nextDialogueButton.Text = _dialogueIndex == _storyDialogues.Length - 1 ? "结束" : "继续";
    }

    private void ShowDrill()
    {
        _interactionPanel.Hide();
        _drillOverlay.Show();
        RefreshExplorationHud();
    }

    private void CloseDrillOverlay()
    {
        _drillOverlay.Hide();
        RefreshExplorationHud();
    }

    private void RefreshExplorationHud()
    {
        if (_explorationHud == null || _dialoguePanel == null || _drillOverlay == null)
            return;

        bool isFreeExploration = !_dialoguePanel.Visible && !_drillOverlay.Visible;
        _explorationHud.Call("set_exploration_visible", isFreeExploration);
    }
}
