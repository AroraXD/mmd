////////////////////////////////////////////////////////////////////////////////////////////////
//  FurShader
//     毛皮シェーダー
//		Program by T.Ogura
//		（MME/基本シェーダー製作 舞力介入P)
//
//                            　MME作成を作成された舞力介入P様
//　　　　　　　　　　　　　素晴らしいモフモフシェーダーを作成されたT.Ogura様
//　　　　　　　　　　　　　両名に感謝です。
//                             パラメータ編集 Kome-ken
////////////////////////////////////////////////////////////////////////////////////////////////


// 毛シェーダー用　コントロールパラメータ
const float FurSupecularPower = 1;      // 毛の光る範囲
const float FurFlowScale = float2(500,1); // 毛の流れる量
const float3 FurColor = float3(1, 1, 1); // 毛の色
//const float3 FurColor = float3(0.9921569, 0.9607843, 0.6); // 毛の色

int FurShellCount = 10; // FurShellの枚数(何枚重ねるか。多いと奇麗だが、重くなる）
const float FurLength = 0.04;  // FurShellの幅（重ねる幅。多いと長くなるが、その分荒くなる）

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
//    float2 SpTex    : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color    : COLOR0;       // ディフューズ色
};

//-----------------------------------------------------------------------------------------------

int nFur;               // 現在描画中のFurShell番号

texture2D fur_tex <
   string ResourceName = "MofMof.tga";// Fur発生テクスチャ。付属のテクスチャは服のボタン部分は黒くなっている
   int Miplevels = 1;
>;
sampler FurSampler = sampler_state {
   texture = <fur_tex>;
};

// 頂点シェーダ （基本形修正のため不必要な計算もしてる）
BufferShadow_OUTPUT Fur_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos+float4(Normal.xyz*FurLength,0)*nFur, WorldViewProjMatrix ); // FurShellを法線方向に膨らませる
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );

    Out.Tex = Tex;// テクスチャ座標
    return Out;
}
float ftime : TIME <bool SyncInEditMode=false;>;

float4 Fur_PS(BufferShadow_OUTPUT IN,  uniform bool useToon) : COLOR
{
    // スペキュラ色計算
   // float3 HalfVector = normalize( normalize(IN.Eye) ); // 毛の光り方。好みの問題かも
    float3 HalfVector = normalize( normalize(IN.Eye)  + -LightDirection );
    float3 Specular = 1-pow(max(0,dot( HalfVector, normalize(IN.Normal) )), FurSupecularPower ) * float3(1,1,1);
    
    float4 Color = IN.Color;
 	float4 TexColor =  tex2D( ObjTexSampler, IN.Tex ) * IN.Color;   // テクスチャカラー

    float2 furDir = float2(0.5,-2.5);//毛の方向法線座標(毛の終端ベクトル。）
    Color.rgb = lerp( TexColor, FurColor, TexColor); // Specular.rによってTexColor -> FurColorに変化させる


	
	// うねうねな実験(GPUに超高負荷)
	//float2 furDire = float2(sin(ftime+IN.Tex.x*20),cos(ftime+IN.Tex.y*40));
    //Color.rgb = float3(1.0-(furDir.x+1.0)/2.0,(furDir.x+1.0)/2.0,(furDir.y+1.0)/2.0) * Specular.r;
     
     // 毛テクスチャから毛部分のアルファを決定。毛先に行くほど薄くなる
    
	Color.w = tex2D( FurSampler, IN.Tex- furDir / FurFlowScale * nFur).r * (1.0-nFur/(FurShellCount-1.0)); 
	
	// return Color; // Furに対するセルフシャドウはあまり良くないので、ここで打ち切るのもあり
    
    // テクスチャ座標に変換
   IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
	
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) { 
        return Color;
    } else {
        float comp;
        if(parthf) {
            // セルフシャドウ mode2
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // セルフシャドウ mode1
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
        }
        return Color * ( 0.7 +  comp *0.3) ; // 影の所は少し暗くする
    }
}

// 材質20番尻尾のモデルです。

technique MainTecBS5  <
	string MMDPass = "object_ss";
	string subSet="32,33,34,35,36,37,38,39,40";
	bool UseTexture = true; bool UseToon = true;

       string Script =
	       "Pass = DrawObject;"
           "LoopByCount=FurShellCount;"
           "LoopGetIndex=nFur;"
           "Pass=Fur;"
           "LoopEnd=;";

> {
    // 下地のジャケットをディフォルトシェーダーで描画する
    pass DrawObject {
    }
    // 毛シェーダー
    pass Fur {
	    AlphaBlendEnable = TRUE;
		ZEnable      = TRUE;
		ZWriteEnable = FALSE;//false;  毛部分はDepthバッファを更新しない(毛の部分の透明処理。Trueだとモデルに関係なく背景が透ける）
		CULLMODE = CCW;

        VertexShader = compile vs_2_0 Fur_VS(true);
        PixelShader  = compile ps_2_0 Fur_PS(true);
    }
}
