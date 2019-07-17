Shader "Custom/myPBR"
{
	Properties
	{
		_MainTex ("Base Color", 2D) = "white" {}
        _Color ("Color", Color) = (0.5019608,0.5019608,0.5019608,1)
        _Specular ("Specular", 2D) = "black" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _reflectmap ("reflectmap", Cube) = "_Skybox" {}
        _reflectionadd ("reflectionadd", Range(0, 10)) = 0
        _colovalue ("colovalue", Range(1, 2)) = 2
        _fresnelvalue ("fresnelvalue", float) = 2
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"
			#include "UnityStandardBRDF.cginc"

			uniform float4 _Color;
            uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
            uniform sampler2D _BumpMap; uniform float4 _BumpMap_ST;
            uniform sampler2D _Specular; uniform float4 _Specular_ST;
            uniform float _reflectionadd;
            uniform samplerCUBE _reflectmap;
            uniform float _colovalue;
            uniform float _fresnelvalue;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float2 uv0 : TEXCOORD1;
				float2 uv1 : TEXCOORD2;

				float3 normal : NORMAL;
                float4 tangent : TANGENT;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float2 uv0 : TEXCOORD1;
				float2 uv1 : TEXCOORD2;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float4 posWorld : TEXCOORD3;
				float3 normalDir : TEXCOORD4;
                float3 tangentDir : TEXCOORD5;
                float3 bitangentDir : TEXCOORD6;
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv0 = TRANSFORM_TEX(v.uv0, _Specular);

				o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.tangentDir = normalize( mul( unity_ObjectToWorld, float4( v.tangent.xyz, 0.0 ) ).xyz );
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
				o.posWorld = mul(unity_ObjectToWorld, v.vertex);

				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
						
			fixed4 frag (v2f i) : SV_Target
			{
				i.normalDir = normalize(i.normalDir);
				float3 normalDirection = i.normalDir;
				float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
				float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
				half NdotV = abs(dot( normalDirection, viewDirection ));
				float3 halfDirection = normalize(viewDirection+lightDirection);
			   half NdotH = saturate(dot( normalDirection, halfDirection ));
                float LdotH = saturate(dot(lightDirection, halfDirection));
				//高光贴图
				fixed4 spcCol = tex2D(_Specular, i.uv0);
				float perceptualRoughness = 1.0 - spcCol.a;
				half roughness = perceptualRoughness*perceptualRoughness;
				float3 specularColor = spcCol.rgb;

				//BRDF d项

				half dCol = GGXTerm(NdotH,roughness);
				//G项
				half gTerm = SmithJointGGXVisibilityTerm(NdotH,NdotV,roughness);
				//F项
				half3 fCol = FresnelTerm(specularColor,LdotH);
				half direSpec = dCol*gTerm*fCol;
				// sample the texture
				fixed4 mainTexCol = tex2D(_MainTex, i.uv);

				float3 diffuse = mainTexCol*_Color*2;
				float3 finCol = diffuse + direSpec;
				float4 col = float4(finCol,1);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
