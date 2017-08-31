////////////////////////////////////////////////////////////////////////////////////////////////
//  FurShader
//     �є�V�F�[�_�[
//		Program by T.Ogura
//		�iMME/��{�V�F�[�_�[���� ���͉��P)
//
//                            �@MME�쐬���쐬���ꂽ���͉��P�l
//�@�@�@�@�@�@�@�@�@�@�@�@�@�f���炵�����t���t�V�F�[�_�[���쐬���ꂽT.Ogura�l
//�@�@�@�@�@�@�@�@�@�@�@�@�@�����Ɋ��ӂł��B
//                             �p�����[�^�ҏW Kome-ken
////////////////////////////////////////////////////////////////////////////////////////////////


// �уV�F�[�_�[�p�@�R���g���[���p�����[�^
const float FurSupecularPower = 1;      // �т̌���͈�
const float FurFlowScale = float2(500,1); // �т̗�����
const float3 FurColor = float3(1, 1, 1); // �т̐F
//const float3 FurColor = float3(0.9921569, 0.9607843, 0.6); // �т̐F

int FurShellCount = 10; // FurShell�̖���(�����d�˂邩�B�����Ɗ�킾���A�d���Ȃ�j
const float FurLength = 0.04;  // FurShell�̕��i�d�˂镝�B�����ƒ����Ȃ邪�A���̕��r���Ȃ�j

// ���@�ϊ��s��
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// �}�e���A���F
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
// ���C�g�F
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // �p�[�X�y�N�e�B�u�t���O
bool     transp;   // �������t���O
bool	 spadd;    // �X�t�B�A�}�b�v���Z�����t���O
#define SKII1    1500
#define SKII2    8000
#define Toon     3

// �I�u�W�F�N�g�̃e�N�X�`��
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

///////////////////////////////////////////////////////////////////////////////////////////////
// �I�u�W�F�N�g�`��i�Z���t�V���h�EON�j

// �V���h�E�o�b�t�@�̃T���v���B"register(s0)"�Ȃ̂�MMD��s0���g���Ă��邩��
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // �ˉe�ϊ����W
    float4 ZCalcTex : TEXCOORD0;    // Z�l
    float2 Tex      : TEXCOORD1;    // �e�N�X�`��
    float3 Normal   : TEXCOORD2;    // �@��
    float3 Eye      : TEXCOORD3;    // �J�����Ƃ̑��Έʒu
//    float2 SpTex    : TEXCOORD4;	 // �X�t�B�A�}�b�v�e�N�X�`�����W
    float4 Color    : COLOR0;       // �f�B�t���[�Y�F
};

//-----------------------------------------------------------------------------------------------

int nFur;               // ���ݕ`�撆��FurShell�ԍ�

texture2D fur_tex <
   string ResourceName = "MofMof.tga";// Fur�����e�N�X�`���B�t���̃e�N�X�`���͕��̃{�^�������͍����Ȃ��Ă���
   int Miplevels = 1;
>;
sampler FurSampler = sampler_state {
   texture = <fur_tex>;
};

// ���_�V�F�[�_ �i��{�`�C���̂��ߕs�K�v�Ȍv�Z�����Ă�j
BufferShadow_OUTPUT Fur_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // �J�������_�̃��[���h�r���[�ˉe�ϊ�
    Out.Pos = mul( Pos+float4(Normal.xyz*FurLength,0)*nFur, WorldViewProjMatrix ); // FurShell��@�������ɖc��܂���
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    // �f�B�t���[�Y�F�{�A���r�G���g�F �v�Z
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );

    Out.Tex = Tex;// �e�N�X�`�����W
    return Out;
}
float ftime : TIME <bool SyncInEditMode=false;>;

float4 Fur_PS(BufferShadow_OUTPUT IN,  uniform bool useToon) : COLOR
{
    // �X�y�L�����F�v�Z
   // float3 HalfVector = normalize( normalize(IN.Eye) ); // �т̌�����B�D�݂̖�肩��
    float3 HalfVector = normalize( normalize(IN.Eye)  + -LightDirection );
    float3 Specular = 1-pow(max(0,dot( HalfVector, normalize(IN.Normal) )), FurSupecularPower ) * float3(1,1,1);
    
    float4 Color = IN.Color;
 	float4 TexColor =  tex2D( ObjTexSampler, IN.Tex ) * IN.Color;   // �e�N�X�`���J���[

    float2 furDir = float2(0.5,-2.5);//�т̕����@�����W(�т̏I�[�x�N�g���B�j
    Color.rgb = lerp( TexColor, FurColor, TexColor); // Specular.r�ɂ����TexColor -> FurColor�ɕω�������


	
	// ���˂��˂Ȏ���(GPU�ɒ�������)
	//float2 furDire = float2(sin(ftime+IN.Tex.x*20),cos(ftime+IN.Tex.y*40));
    //Color.rgb = float3(1.0-(furDir.x+1.0)/2.0,(furDir.x+1.0)/2.0,(furDir.y+1.0)/2.0) * Specular.r;
     
     // �уe�N�X�`������ѕ����̃A���t�@������B�ѐ�ɍs���قǔ����Ȃ�
    
	Color.w = tex2D( FurSampler, IN.Tex- furDir / FurFlowScale * nFur).r * (1.0-nFur/(FurShellCount-1.0)); 
	
	// return Color; // Fur�ɑ΂���Z���t�V���h�E�͂��܂�ǂ��Ȃ��̂ŁA�����őł��؂�̂�����
    
    // �e�N�X�`�����W�ɕϊ�
   IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
	
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) { 
        return Color;
    } else {
        float comp;
        if(parthf) {
            // �Z���t�V���h�E mode2
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // �Z���t�V���h�E mode1
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
        }
        return Color * ( 0.7 +  comp *0.3) ; // �e�̏��͏����Â�����
    }
}

// �ގ�20�ԐK���̃��f���ł��B

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
    // ���n�̃W���P�b�g���f�B�t�H���g�V�F�[�_�[�ŕ`�悷��
    pass DrawObject {
    }
    // �уV�F�[�_�[
    pass Fur {
	    AlphaBlendEnable = TRUE;
		ZEnable      = TRUE;
		ZWriteEnable = FALSE;//false;  �ѕ�����Depth�o�b�t�@���X�V���Ȃ�(�т̕����̓��������BTrue���ƃ��f���Ɋ֌W�Ȃ��w�i��������j
		CULLMODE = CCW;

        VertexShader = compile vs_2_0 Fur_VS(true);
        PixelShader  = compile ps_2_0 Fur_PS(true);
    }
}
