const assetPathPrefix = "https://www.figma.com/api/mcp/asset/2e80aa09-0dcd-4a7b-a52d-6ae7eddb5cf9";
const imgVector = `${assetPathPrefix}/98d2f.svg`;

type WindowControlsStandardProps = {
  className?: string;
  active?: "True";
  mode?: "Dark";
};

function WindowControlsStandard({ className, active = "True", mode = "Dark" }: WindowControlsStandardProps) {
  return (
    <div className={className || "content-stretch flex gap-[9px] items-center pointer-events-none pr-[8px] relative"} data-node-id="4002:1396">
      <div className="relative rounded-[100px] shrink-0 size-[14px]" data-node-id="4002:1397" data-name="Close">
        <div aria-hidden className="absolute bg-[#f06e6a] inset-0 rounded-[100px]" />
        <div className="absolute inset-0 rounded-[inherit] shadow-[inset_0px_1.25px_0.5px_-0.75px_#999,inset_0px_-1.25px_0.5px_-0.75px_#808080,inset_0px_5px_4px_-3px_#262626,inset_0px_0px_3px_0px_rgba(153,31,0,0.6),inset_0px_17px_4px_-10px_rgba(153,31,0,0.4)]" />
      </div>
      <div className="relative rounded-[100px] shrink-0 size-[14px]" data-node-id="4002:1398" data-name="Minimize">
        <div aria-hidden className="absolute bg-[#ffcd30] inset-0 rounded-[100px]" />
        <div className="absolute inset-0 rounded-[inherit] shadow-[inset_0px_1.25px_0.5px_-0.75px_#999,inset_0px_-1.25px_0.5px_-0.75px_#808080,inset_0px_5px_4px_-3px_#161616,inset_0px_0px_3px_0px_#4d2e0f,inset_0px_17px_4px_-10px_#4d2e0f]" />
      </div>
      <div className="relative rounded-[100px] shrink-0 size-[14px]" data-node-id="4002:1399" data-name="Zoom">
        <div aria-hidden className="absolute bg-[#58c73b] inset-0 rounded-[100px]" />
        <div className="absolute inset-0 rounded-[inherit] shadow-[inset_0px_1.25px_0.5px_-0.75px_#999,inset_0px_-1.25px_0.5px_-0.75px_#808080,inset_0px_5px_4px_-3px_#262626,inset_0px_0px_3px_0px_rgba(17,51,0,0.8),inset_0px_17px_4px_-10px_rgba(17,51,0,0.6)]" />
      </div>
    </div>
  );
}

export default function FirstScreen() {
  return (
    <div className="bg-[#151515] content-stretch flex flex-col items-center overflow-clip relative rounded-[22px] size-full" data-node-id="4002:1390" data-name="First screen">
      <div className="content-stretch flex flex-col gap-[10px] items-start p-[22px] relative shrink-0 w-full" data-node-id="4002:1435">
        <WindowControlsStandard className="content-stretch flex gap-[9px] items-center pointer-events-none pr-[8px] relative shrink-0" />
        <div className="-translate-x-1/2 absolute bg-[rgba(255,255,255,0.05)] content-stretch flex items-center left-1/2 p-[4px] rounded-[67px] top-[14px]" data-node-id="4008:2569">
          <div className="bg-[rgba(0,0,0,0.5)] content-stretch flex items-center justify-center px-[12px] py-[11px] relative rounded-[39px] shrink-0" data-node-id="4008:2570">
            <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[14px] text-center text-white whitespace-nowrap" data-node-id="4008:2571" style={{ fontVariationSettings: '"wdth" 100' }}>
              <p className="leading-[16px]">Auto</p>
            </div>
          </div>
          <div className="content-stretch flex items-center justify-center px-[12px] py-[11px] relative rounded-[39px] shrink-0" data-node-id="4008:2572">
            <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[14px] text-center text-white whitespace-nowrap" data-node-id="4008:2573" style={{ fontVariationSettings: '"wdth" 100' }}>
              <p className="leading-[16px]">Manual</p>
            </div>
          </div>
        </div>
      </div>
      <div className="content-stretch flex flex-[1_0_0] flex-col items-center justify-center min-h-px p-[20px] relative w-full" data-node-id="4002:1473">
        <div className="bg-[#121212] border-[#333] border-[1.5px] border-dashed content-stretch flex flex-[1_0_0] flex-col gap-[18px] items-center justify-center min-h-px overflow-clip px-[152px] py-[113px] relative rounded-[8px] w-full" data-node-id="4002:1472">
          <div className="h-[69.985px] relative shrink-0 w-[67.068px]" data-node-id="4002:1475" data-name="Vector">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgVector} />
          </div>
          <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Semibold'] font-[590] justify-center leading-[0] relative shrink-0 text-[#333] text-[16px] text-center whitespace-nowrap" data-node-id="4002:1476" style={{ fontVariationSettings: '"wdth" 100' }}>
            <p className="leading-[16px]">Drop your files</p>
          </div>
        </div>
      </div>
    </div>
  );
}

SUPER CRITICAL: The generated React+Tailwind code MUST be converted to match the target project's technology stack and styling system.
1. Analyze the target codebase to identify: technology stack, styling approach, component patterns, and design tokens
2. Convert React syntax to the target framework/library
3. Transform all Tailwind classes to the target styling system while preserving exact visual design
4. Follow the project's existing patterns and conventions
DO NOT install any Tailwind as a dependency unless the user instructs you to do so.


Node ids have been added to the code as data attributes, e.g. `data-node-id="1:2"`.

The generated code contains image and SVG URL constants, e.g. const image = `${assetPathPrefix}/<asset file name>`, where assetPathPrefix is declared once at the top of the code and every asset URL interpolates it. These URLs are temporary download sources and expire after 7 days. Download each asset into the project with curl -L, then replace its URL in the generated code with a reference to the downloaded asset. Never use the temporary URLs as runtime image sources.
